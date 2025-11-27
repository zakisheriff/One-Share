#include "MTPBridge.hpp"
#include <libmtp.h>
#include <stdlib.h>
#include <string.h>
#include <iostream>
#include <vector>
#include <chrono>

// Global device pointer (simplified for single device support)
static LIBMTP_mtpdevice_t *device = NULL;

bool mtp_connect() {
    if (device != NULL) {
        return true; // Already connected
    }

    LIBMTP_Init();

    LIBMTP_raw_device_t *raw_devices;
    int num_raw_devices;

    LIBMTP_error_number_t err = LIBMTP_Detect_Raw_Devices(&raw_devices, &num_raw_devices);

    if (err != LIBMTP_ERROR_NONE || num_raw_devices == 0) {
        return false;
    }

    // Connect to the first device
    device = LIBMTP_Open_Raw_Device_Uncached(&raw_devices[0]);
    
    // Free raw devices
    free(raw_devices); // LIBMTP_Detect_Raw_Devices allocates this array

    return (device != NULL);
}

void mtp_disconnect() {
    if (device != NULL) {
        LIBMTP_Release_Device(device);
        device = NULL;
    }
}

bool mtp_reconnect() {
    mtp_disconnect();
    return mtp_connect();
}

bool mtp_is_connected() {
    return (device != NULL);
}

bool mtp_check_storage() {
    if (device == NULL) return false;
    
    // Refresh storage list
    int result = LIBMTP_Get_Storage(device, LIBMTP_STORAGE_SORTBY_NOTSORTED);
    
    // LIBMTP_Get_Storage returns 0 on success, -1 on failure
    if (result != 0) {
        // Error getting storage, might be disconnected or locked
        return false;
    }
    
    // Check if storage info is available and valid
    if (device->storage == NULL) {
        return false;
    }
    
    // Additional safety check - verify storage ID is valid
    if (device->storage->id == 0) {
        return false;
    }
    
    return true;
}

char* mtp_get_device_name() {
    if (!device) return NULL;
    char* name = LIBMTP_Get_Modelname(device);
    // Note: Caller is responsible for freeing this string
    return name;
}

MTPFileInfo* mtp_list_files(uint32_t storage_id, uint32_t parent_id, int* count) {
    if (!device || !count) {
        if (count) *count = 0;
        return NULL;
    }

    // If storage_id is 0, try to get the first storage
    if (storage_id == 0) {
         // Ensure device parameters are up to date
         int result = LIBMTP_Get_Storage(device, LIBMTP_STORAGE_SORTBY_NOTSORTED);
         if (result != 0 || device->storage == NULL) {
             *count = 0;
             return NULL;
         }
         storage_id = device->storage->id;
         
         // Verify storage_id is valid
         if (storage_id == 0) {
             *count = 0;
             return NULL;
         }
    }

    LIBMTP_file_t *files = LIBMTP_Get_Files_And_Folders(device, storage_id, parent_id);
    
    // Count files
    int c = 0;
    LIBMTP_file_t *f = files;
    while (f != NULL) {
        c++;
        f = f->next;
    }
    *count = c;

    if (c == 0 || files == NULL) {
        // Free the libmtp file list if we have one
        LIBMTP_file_t *tmp;
        while (files != NULL) {
            tmp = files;
            files = files->next;
            LIBMTP_destroy_file_t(tmp);
        }
        return NULL;
    }

    MTPFileInfo* result = (MTPFileInfo*)malloc(sizeof(MTPFileInfo) * c);
    if (!result) {
        // Memory allocation failed, clean up and return NULL
        LIBMTP_file_t *tmp;
        while (files != NULL) {
            tmp = files;
            files = files->next;
            LIBMTP_destroy_file_t(tmp);
        }
        *count = 0;
        return NULL;
    }
    
    f = files;
    int i = 0;
    while (f != NULL && i < c) {
        result[i].id = f->item_id;
        result[i].storage_id = f->storage_id;
        // Add null check for filename
        if (f->filename != NULL) {
            strncpy(result[i].name, f->filename, 255);
        } else {
            result[i].name[0] = '\0';
        }
        result[i].name[255] = '\0';
        result[i].size = f->filesize;
        result[i].is_folder = (f->filetype == LIBMTP_FILETYPE_FOLDER);
        result[i].parent_id = f->parent_id;
        result[i].modification_date = f->modificationdate;
        
        i++;
        f = f->next;
    }

    // Free the libmtp file list (it's a linked list)
    LIBMTP_file_t *tmp;
    while (files != NULL) {
        tmp = files;
        files = files->next;
        LIBMTP_destroy_file_t(tmp);
    }

    return result;
}

void mtp_free_files(MTPFileInfo* files) {
    // Free the array of MTPFileInfo structs
    // Note: This only frees the array itself, not any strings within the structs
    // since we use fixed-size char arrays rather than dynamically allocated strings
    if (files) {
        free(files);
    }
}

// Progress callback wrapper
// We need a struct to hold both the callback function pointer and the context
struct MTPBridgeCallbackData {
    MTPProgressCallback callback;
    const void* context;
    uint64_t lastReportedBytes;
    std::chrono::steady_clock::time_point lastReportTime;
};

static int mtp_bridge_progress_wrapper(uint64_t const sent, uint64_t const total, void const * const data) {
    MTPBridgeCallbackData* cbData = (MTPBridgeCallbackData*)data;
    if (cbData && cbData->callback) {
        // Throttle callbacks to reduce overhead
        // Only report every 1MB or every 100ms, whichever comes first
        auto now = std::chrono::steady_clock::now();
        uint64_t bytesSinceLastReport = sent - cbData->lastReportedBytes;
        auto timeSinceLastReport = std::chrono::duration_cast<std::chrono::milliseconds>(now - cbData->lastReportTime).count();
        
        const uint64_t MIN_BYTES_DELTA = 1024 * 1024; // 1 MB
        const int64_t MIN_TIME_DELTA_MS = 100; // 100 ms
        
        // Always report first and last callback
        bool shouldReport = (sent == 0) || 
                           (sent == total) || 
                           (bytesSinceLastReport >= MIN_BYTES_DELTA) || 
                           (timeSinceLastReport >= MIN_TIME_DELTA_MS);
        
        if (shouldReport) {
            cbData->callback(sent, total, cbData->context);
            cbData->lastReportedBytes = sent;
            cbData->lastReportTime = now;
        }
    }
    return 0; // Return 0 to continue
}

int mtp_download_file(uint32_t file_id, const char* dest_path, MTPProgressCallback callback, const void* context) {
    if (!device) return -1;
    
    MTPBridgeCallbackData cbData = { callback, context, 0, std::chrono::steady_clock::now() };
    
    int ret = LIBMTP_Get_File_To_File(device, file_id, dest_path, mtp_bridge_progress_wrapper, (void*)&cbData);
    
    // Check for specific error conditions
    if (ret != 0) {
        // Log error or handle specific cases
        // For now, just return the error code
    }
    
    return ret;
}

int mtp_upload_file(const char* source_path, uint32_t storage_id, uint32_t parent_id, const char* filename, uint64_t size, MTPProgressCallback callback, const void* context) {
    if (!device) return -1;
    
    // If storage_id is 0, use first storage
    if (storage_id == 0) {
         LIBMTP_Get_Storage(device, LIBMTP_STORAGE_SORTBY_NOTSORTED);
         if (device->storage) {
             storage_id = device->storage->id;
         } else {
             return -1;
         }
    }

    LIBMTP_file_t *newfile = LIBMTP_new_file_t();
    newfile->filename = strdup(filename);
    newfile->filesize = size;
    newfile->parent_id = parent_id;
    newfile->storage_id = storage_id;
    newfile->filetype = LIBMTP_FILETYPE_UNKNOWN; // Let libmtp guess or set generic

    MTPBridgeCallbackData cbData = { callback, context, 0, std::chrono::steady_clock::now() };

    int ret = LIBMTP_Send_File_From_File(device, source_path, newfile, mtp_bridge_progress_wrapper, (void*)&cbData);
    
    LIBMTP_destroy_file_t(newfile);
    
    // Check for specific error conditions
    if (ret != 0) {
        // Log error or handle specific cases
        // For now, just return the error code
    }
    
    return ret;
}

int mtp_delete_file(uint32_t file_id) {
    if (!device) return -1;
    
    int ret = LIBMTP_Delete_Object(device, file_id);
    return ret;
}

#ifdef __cplusplus

#endif
