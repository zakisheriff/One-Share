#ifndef iOSBridge_h
#define iOSBridge_h

#include <stdio.h>
#include <stdint.h>
#include <stdbool.h>

#ifdef __cplusplus
extern "C" {
#endif

// Structs to pass data to Swift
typedef struct {
    uint64_t id;
    char name[256];
    uint64_t size;
    bool is_directory;
    uint64_t modification_date; // Unix timestamp
} iOSFileInfo;

typedef struct {
    char device_name[256];
    char device_udid[256];
    char product_type[256]; // e.g., "iPhone10,1"
} iOSDeviceInfo;

// Device connection states
typedef enum {
    IOS_DEVICE_DISCONNECTED,
    IOS_DEVICE_CONNECTING,
    IOS_DEVICE_CONNECTED,
    IOS_DEVICE_TRUST_REQUIRED,
    IOS_DEVICE_LOCKED,
    IOS_DEVICE_ERROR
} iOSDeviceState;

// Callback for progress: transferred bytes, total bytes, context
typedef void (*iOSProgressCallback)(uint64_t sent, uint64_t total, const void* context);

// Device Management
bool ios_connect(void);
void ios_disconnect(void);
bool ios_is_connected(void);
iOSDeviceState ios_get_device_state(void);
iOSDeviceInfo ios_get_device_info(void);
char* ios_get_device_name(void);

// File Operations
iOSFileInfo* ios_list_files(const char* path, int* count);
void ios_free_files(iOSFileInfo* files);

// Transfer Operations
int ios_download_file(const char* device_path, const char* dest_path, iOSProgressCallback callback, const void* context);
int ios_upload_file(const char* source_path, const char* device_path, iOSProgressCallback callback, const void* context);
int ios_delete_file(const char* device_path);
int ios_create_directory(const char* device_path);

// House Arrest (App Sandbox Access)
bool ios_house_arrest_start(const char* bundle_id);
void ios_house_arrest_stop(void);
bool ios_house_arrest_is_active(void);

#ifdef __cplusplus
}
#endif

#endif /* iOSBridge_h */