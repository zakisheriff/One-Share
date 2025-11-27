#include "iOSBridge.h"
#include <libimobiledevice/libimobiledevice.h>
#include <libimobiledevice/lockdown.h>
#include <libimobiledevice/afc.h>
#include <libimobiledevice/house_arrest.h>

#include <stdlib.h>
#include <string.h>
#include <iostream>
#include <vector>
#include <chrono>
#include <thread>

// Global device pointers
static idevice_t device = NULL;
static lockdownd_client_t lockdown_client = NULL;
static afc_client_t afc_client = NULL;
static house_arrest_client_t house_arrest_client = NULL;
static bool house_arrest_active = false;

// Progress callback wrapper structure
struct iOSBridgeCallbackData {
    iOSProgressCallback callback;
    const void* context;
    uint64_t lastReportedBytes;
    std::chrono::steady_clock::time_point lastReportTime;
};

// Helper function to convert AFC error to integer code
static int afc_error_to_int(afc_error_t err) {
    switch (err) {
        case AFC_E_SUCCESS: return 0;
        case AFC_E_INVALID_ARG: return -1;
        case AFC_E_NO_RESOURCES: return -2;
        case AFC_E_PERM_DENIED: return -3;
        case AFC_E_OBJECT_NOT_FOUND: return -4;
        case AFC_E_IO_ERROR: return -5;
        default: return -100;
    }
}

// Simple hash function for string
static uint64_t simple_hash(const std::string& str) {
    uint64_t hash = 5381;
    for (char c : str) {
        hash = ((hash << 5) + hash) + c; // hash * 33 + c
    }
    return hash;
}

// Helper function to check device trust/lock state
static iOSDeviceState check_device_state() {
    if (!device) {
        return IOS_DEVICE_DISCONNECTED;
    }
    
    // Try to connect to lockdown
    if (!lockdown_client) {
        lockdownd_error_t ldret = lockdownd_client_new_with_handshake(device, &lockdown_client, "Lumen");
        if (ldret != LOCKDOWN_E_SUCCESS) {
            switch (ldret) {
                case LOCKDOWN_E_INVALID_HOST_ID:
                    return IOS_DEVICE_TRUST_REQUIRED;
                case LOCKDOWN_E_PASSWORD_PROTECTED:
                    return IOS_DEVICE_LOCKED;
                default:
                    return IOS_DEVICE_ERROR;
            }
        }
    }
    
    // Try to connect to AFC service
    if (!afc_client) {
        afc_error_t afc_ret = afc_client_start_service(device, &afc_client, "Lumen");
        if (afc_ret != AFC_E_SUCCESS) {
            // Try again with house arrest if we have a bundle ID
            return IOS_DEVICE_CONNECTED; // We're connected but can't access filesystem yet
        }
    }
    
    return IOS_DEVICE_CONNECTED;
}

bool ios_connect() {
    if (device != NULL) {
        // Already connected, check state
        return (check_device_state() == IOS_DEVICE_CONNECTED);
    }
    
    // Try to connect to any iOS device
    idevice_error_t err = idevice_new(&device, NULL);
    if (err != IDEVICE_E_SUCCESS) {
        return false;
    }
    
    // Check device state
    iOSDeviceState state = check_device_state();
    return (state == IOS_DEVICE_CONNECTED);
}

void ios_disconnect() {
    if (house_arrest_client) {
        house_arrest_client_free(house_arrest_client);
        house_arrest_client = NULL;
        house_arrest_active = false;
    }
    
    if (afc_client) {
        afc_client_free(afc_client);
        afc_client = NULL;
    }
    
    if (lockdown_client) {
        lockdownd_client_free(lockdown_client);
        lockdown_client = NULL;
    }
    
    if (device) {
        idevice_free(device);
        device = NULL;
    }
}

bool ios_is_connected() {
    return (device != NULL && check_device_state() == IOS_DEVICE_CONNECTED);
}

iOSDeviceState ios_get_device_state() {
    return check_device_state();
}

iOSDeviceInfo ios_get_device_info() {
    iOSDeviceInfo info = {};
    
    if (!device || !lockdown_client) {
        return info;
    }
    
    // Get device UDID
    char* udid = NULL;
    idevice_get_udid(device, &udid);
    if (udid) {
        strncpy(info.device_udid, udid, sizeof(info.device_udid) - 1);
        free(udid);
    }
    
    // Get device name
    char* device_name = NULL;
    lockdownd_get_device_name(lockdown_client, &device_name);
    if (device_name) {
        strncpy(info.device_name, device_name, sizeof(info.device_name) - 1);
        free(device_name);
    }
    
    // Get product type
    plist_t node = NULL;
    lockdownd_get_value(lockdown_client, NULL, "ProductType", &node);
    if (node && plist_get_node_type(node) == PLIST_STRING) {
        char* product_type = NULL;
        plist_get_string_val(node, &product_type);
        if (product_type) {
            strncpy(info.product_type, product_type, sizeof(info.product_type) - 1);
            free(product_type);
        }
    }
    if (node) {
        plist_free(node);
    }
    
    return info;
}

char* ios_get_device_name() {
    if (!device || !lockdown_client) {
        return NULL;
    }
    
    char* device_name = NULL;
    lockdownd_get_device_name(lockdown_client, &device_name);
    return device_name;
}

iOSFileInfo* ios_list_files(const char* path, int* count) {
    if (!afc_client || !path || !count) {
        *count = 0;
        return NULL;
    }
    
    // Ensure we have a leading slash
    std::string normalized_path = path;
    if (normalized_path.empty() || normalized_path[0] != '/') {
        normalized_path = "/" + normalized_path;
    }
    
    // Get directory listing
    char** list = NULL;
    afc_error_t err = afc_read_directory(afc_client, normalized_path.c_str(), &list);
    if (err != AFC_E_SUCCESS) {
        *count = 0;
        return NULL;
    }
    
    // Count entries
    int entry_count = 0;
    if (list) {
        for (int i = 0; list[i]; i++) {
            entry_count++;
        }
    }
    
    if (entry_count == 0) {
        afc_dictionary_free(list);
        *count = 0;
        return NULL;
    }
    
    // Allocate result array
    iOSFileInfo* result = (iOSFileInfo*)malloc(sizeof(iOSFileInfo) * entry_count);
    *count = entry_count;
    
    // Process each entry
    for (int i = 0; i < entry_count; i++) {
        std::string full_path = normalized_path;
        if (full_path.back() != '/') {
            full_path += "/";
        }
        full_path += list[i];
        
        // Get file info
        char** file_info = NULL;
        err = afc_get_file_info(afc_client, full_path.c_str(), &file_info);
        if (err != AFC_E_SUCCESS || !file_info) {
            // Set default values
            result[i].id = simple_hash(full_path); // Simple hash as ID
            strncpy(result[i].name, list[i], sizeof(result[i].name) - 1);
            result[i].size = 0;
            result[i].is_directory = (strcmp(list[i], ".") == 0 || strcmp(list[i], "..") == 0);
            result[i].modification_date = 0;
        } else {
            // Parse file info
            result[i].id = simple_hash(full_path);
            strncpy(result[i].name, list[i], sizeof(result[i].name) - 1);
            result[i].size = 0;
            result[i].is_directory = false;
            result[i].modification_date = 0;
            
            // Extract info from dictionary
            for (int j = 0; file_info[j]; j += 2) {
                if (!file_info[j+1]) continue;
                
                if (strcmp(file_info[j], "st_size") == 0) {
                    result[i].size = strtoull(file_info[j+1], NULL, 10);
                } else if (strcmp(file_info[j], "st_ifmt") == 0) {
                    result[i].is_directory = (strcmp(file_info[j+1], "S_IFDIR") == 0);
                } else if (strcmp(file_info[j], "st_mtime") == 0) {
                    result[i].modification_date = strtoull(file_info[j+1], NULL, 10);
                }
            }
            
            afc_dictionary_free(file_info);
        }
    }
    
    afc_dictionary_free(list);
    return result;
}

void ios_free_files(iOSFileInfo* files) {
    if (files) {
        free(files);
    }
}

// Progress callback wrapper
static void ios_bridge_progress_wrapper(uint64_t sent, uint64_t total, void* context) {
    iOSBridgeCallbackData* cbData = (iOSBridgeCallbackData*)context;
    if (cbData && cbData->callback) {
        // Throttle callbacks to reduce overhead
        auto now = std::chrono::steady_clock::now();
        uint64_t bytesSinceLastReport = sent - cbData->lastReportedBytes;
        auto timeSinceLastReport = std::chrono::duration_cast<std::chrono::milliseconds>(now - cbData->lastReportTime).count();
        
        const uint64_t MIN_BYTES_DELTA = 1024 * 1024; // 1 MB
        const int64_t MIN_TIME_DELTA_MS = 100; // 100 ms
        
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
}

int ios_download_file(const char* device_path, const char* dest_path, iOSProgressCallback callback, const void* context) {
    if (!afc_client || !device_path || !dest_path) {
        return -1;
    }
    
    iOSBridgeCallbackData cbData = { callback, context, 0, std::chrono::steady_clock::now() };
    
    // Open source file on device
    uint64_t afc_handle = 0;
    afc_error_t err = afc_file_open(afc_client, device_path, AFC_FOPEN_RDONLY, &afc_handle);
    if (err != AFC_E_SUCCESS) {
        return afc_error_to_int(err);
    }
    
    // Open destination file on host
    FILE* dest_file = fopen(dest_path, "wb");
    if (!dest_file) {
        afc_file_close(afc_client, afc_handle);
        return -5; // IO error
    }
    
    // Copy data
    char buffer[8192];
    uint64_t total_bytes = 0;
    uint64_t bytes_written = 0;
    
    // Get file size for progress reporting
    char** file_info = NULL;
    err = afc_get_file_info(afc_client, device_path, &file_info);
    if (err == AFC_E_SUCCESS && file_info) {
        for (int i = 0; file_info[i]; i += 2) {
            if (file_info[i+1] && strcmp(file_info[i], "st_size") == 0) {
                total_bytes = strtoull(file_info[i+1], NULL, 10);
                break;
            }
        }
        afc_dictionary_free(file_info);
    }
    
    while (true) {
        uint32_t bytes_read = 0;
        err = afc_file_read(afc_client, afc_handle, buffer, sizeof(buffer), &bytes_read);
        if (err != AFC_E_SUCCESS || bytes_read == 0) {
            break;
        }
        
        size_t written = fwrite(buffer, 1, bytes_read, dest_file);
        if (written != bytes_read) {
            // Error writing to destination
            fclose(dest_file);
            afc_file_close(afc_client, afc_handle);
            return -5; // IO error
        }
        
        bytes_written += written;
        
        // Report progress
        if (callback && total_bytes > 0) {
            ios_bridge_progress_wrapper(bytes_written, total_bytes, &cbData);
        }
    }
    
    fclose(dest_file);
    afc_file_close(afc_client, afc_handle);
    
    return (err == AFC_E_SUCCESS) ? 0 : afc_error_to_int(err);
}

int ios_upload_file(const char* source_path, const char* device_path, iOSProgressCallback callback, const void* context) {
    if (!afc_client || !source_path || !device_path) {
        return -1;
    }
    
    iOSBridgeCallbackData cbData = { callback, context, 0, std::chrono::steady_clock::now() };
    
    // Open source file on host
    FILE* source_file = fopen(source_path, "rb");
    if (!source_file) {
        return -5; // IO error
    }
    
    // Get file size for progress reporting
    fseek(source_file, 0, SEEK_END);
    uint64_t total_bytes = ftell(source_file);
    fseek(source_file, 0, SEEK_SET);
    
    // Open destination file on device
    uint64_t afc_handle = 0;
    afc_error_t err = afc_file_open(afc_client, device_path, AFC_FOPEN_WRONLY, &afc_handle);
    if (err != AFC_E_SUCCESS) {
        fclose(source_file);
        return afc_error_to_int(err);
    }
    
    // Copy data
    char buffer[8192];
    uint64_t bytes_read = 0;
    
    while (!feof(source_file)) {
        size_t read = fread(buffer, 1, sizeof(buffer), source_file);
        if (read == 0) {
            break;
        }
        
        uint32_t bytes_written = 0;
        err = afc_file_write(afc_client, afc_handle, buffer, read, &bytes_written);
        if (err != AFC_E_SUCCESS || bytes_written != read) {
            fclose(source_file);
            afc_file_close(afc_client, afc_handle);
            return afc_error_to_int(err);
        }
        
        bytes_read += read;
        
        // Report progress
        if (callback && total_bytes > 0) {
            ios_bridge_progress_wrapper(bytes_read, total_bytes, &cbData);
        }
    }
    
    fclose(source_file);
    afc_file_close(afc_client, afc_handle);
    
    return 0;
}

int ios_delete_file(const char* device_path) {
    if (!afc_client || !device_path) {
        return -1;
    }
    
    // Try to delete as file first
    afc_error_t err = afc_remove_path(afc_client, device_path);
    if (err == AFC_E_SUCCESS) {
        return 0;
    }
    
    // If that fails, try as directory
    err = afc_remove_path_and_contents(afc_client, device_path);
    return afc_error_to_int(err);
}

int ios_create_directory(const char* device_path) {
    if (!afc_client || !device_path) {
        return -1;
    }
    
    afc_error_t err = afc_make_directory(afc_client, device_path);
    return afc_error_to_int(err);
}

bool ios_house_arrest_start(const char* bundle_id) {
    if (!device || !bundle_id) {
        return false;
    }
    
    // Disconnect existing AFC client if active
    if (afc_client) {
        afc_client_free(afc_client);
        afc_client = NULL;
    }
    
    // Connect to house arrest service
    house_arrest_error_t herr = house_arrest_client_start_service(device, &house_arrest_client, "Lumen");
    if (herr != HOUSE_ARREST_E_SUCCESS) {
        return false;
    }
    
    // Send command to access app sandbox
    herr = house_arrest_send_command(house_arrest_client, "VendDocuments", bundle_id);
    if (herr != HOUSE_ARREST_E_SUCCESS) {
        house_arrest_client_free(house_arrest_client);
        house_arrest_client = NULL;
        return false;
    }
    
    // Get AFC client from house arrest
    afc_error_t aerr = afc_client_new_from_house_arrest_client(house_arrest_client, &afc_client);
    if (aerr != AFC_E_SUCCESS) {
        house_arrest_client_free(house_arrest_client);
        house_arrest_client = NULL;
        return false;
    }
    
    house_arrest_active = true;
    return true;
}

void ios_house_arrest_stop() {
    if (house_arrest_active) {
        if (afc_client) {
            afc_client_free(afc_client);
            afc_client = NULL;
        }
        
        if (house_arrest_client) {
            house_arrest_client_free(house_arrest_client);
            house_arrest_client = NULL;
        }
        
        house_arrest_active = false;
    }
}

bool ios_house_arrest_is_active() {
    return house_arrest_active;
}