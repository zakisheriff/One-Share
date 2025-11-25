#ifndef MTPBridge_hpp
#define MTPBridge_hpp

#include <stdio.h>
#include <stdint.h>
#include <stdbool.h>

#ifdef __cplusplus
extern "C" {
#endif

// Structs to pass data to Swift
typedef struct {
    uint32_t id;
    uint32_t storage_id;
    char name[256];
    uint64_t size;
    bool is_folder;
    uint32_t parent_id;
    // Add more fields if needed (e.g., modification date)
} MTPFileInfo;

typedef struct {
    char model[256];
    char serial[256];
    // We might need to handle multiple storages, but for simplicity let's assume primary
} MTPDeviceInfo;

// Callback for progress: transferred bytes, total bytes, context
typedef void (*MTPProgressCallback)(uint64_t sent, uint64_t total, const void* context);

// Functions
bool mtp_connect(void);
bool mtp_reconnect(void);
void mtp_disconnect(void);
bool mtp_is_connected(void);
bool mtp_check_storage(void);
char* mtp_get_device_name(void);

// Listing
// Returns an array of MTPFileInfo, caller must free it with mtp_free_files
MTPFileInfo* mtp_list_files(uint32_t storage_id, uint32_t parent_id, int* count);
void mtp_free_files(MTPFileInfo* files);

// Transfer
// Returns 0 on success, non-zero on error
int mtp_download_file(uint32_t file_id, const char* dest_path, MTPProgressCallback callback, const void* context);
int mtp_upload_file(const char* source_path, uint32_t storage_id, uint32_t parent_id, const char* filename, uint64_t size, MTPProgressCallback callback, const void* context);
int mtp_delete_file(uint32_t file_id);

#ifdef __cplusplus
}
#endif

#endif /* MTPBridge_hpp */
