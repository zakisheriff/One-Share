# Lumen iOS Integration Plan

## Architecture Overview

Lumen now supports both Android (MTP) and iOS (AFC + HouseArrest) devices with a unified interface. The architecture follows a modular approach with clear separation of concerns:

```
┌─────────────────────────────────────────────────────────────┐
│                    Lumen Application                        │
├─────────────────────────────────────────────────────────────┤
│  MainView.swift          │  FileBrowserView.swift           │
│  SidebarView.swift       │  TransferManager.swift           │
├─────────────────────────────────────────────────────────────┤
│              Unified FileService Protocol                   │
│         ┌─────────────┐    ┌────────────────┐              │
│         │MTPService   │    │iOSDeviceService│              │
│         │(Android)    │    │(iOS)           │              │
│         └─────────────┘    └────────────────┘              │
├─────────────────────────────────────────────────────────────┤
│      iOSBridge (Objective-C++)    │     libmtp/libimobiledevice  │
│  ┌─────────────────────────────┐  │  ┌─────────────────────────┐ │
│  │ios_bridge.mm                │  │  │                         │ │
│  │- Device Detection           │  │  │                         │ │
│  │- AFC Operations             │  │  │                         │ │
│  │- HouseArrest Operations     │  │  │                         │ │
│  │- Connection Management      │  │  │                         │ │
│  └─────────────────────────────┘  │  │                         │ │
├─────────────────────────────────────────────────────────────┤
│               Native System Libraries                       │
└─────────────────────────────────────────────────────────────┘
```

## Module Structure

### 1. iOSBridge Module

Located at `Lumen/iOSBridge/`

- **Header files**: `iOSBridge/include/iOSBridge.h`
- **Implementation**: `iOSBridge/src/iOSBridge.cpp`
- **Swift bridging**: `iOSBridge/ios_bridge.mm`

Key functions:

- `ios_connect()` - Establish connection to iOS device
- `ios_list_files()` - List files in a directory
- `ios_download_file()` - Download file from iOS device
- `ios_upload_file()` - Upload file to iOS device
- `ios_delete_file()` - Delete file on iOS device
- `ios_house_arrest_start()` - Access app sandbox via HouseArrest
- `ios_house_arrest_stop()` - Close HouseArrest session

### 2. iOSDeviceService

Located at `Lumen/iOSDeviceService.swift`

Implements the FileService protocol for iOS devices:

- Connection state management
- File operations with caching
- Error handling with user-friendly messages
- Device information retrieval

### 3. DeviceManager

Located at `Lumen/DeviceManager.swift`

Centralized device management:

- Tracks connected Android and iOS devices
- Provides unified interface for device operations
- Manages connection state observers

## File Access Flow

### iOS Device Connection

1. DeviceManager initializes iOSDeviceService
2. iOSDeviceService starts device monitoring timer
3. Periodic checks for connected iOS devices
4. When device is detected, connection state updates
5. UI reflects device connection status

### File Operations

1. User navigates to iOS device in sidebar
2. FileBrowserView requests file list from iOSDeviceService
3. iOSDeviceService calls iOSBridge functions
4. iOSBridge communicates with libimobiledevice
5. Results are cached and returned to UI
6. Files are displayed with native macOS styling

### Transfer Operations

1. User initiates file transfer (drag-drop or copy-paste)
2. TransferManager determines source and destination
3. Appropriate transfer method is called:
   - iOS to Mac: `ios_download_file()`
   - Mac to iOS: `ios_upload_file()`
4. Progress is reported through callback mechanisms
5. Transfer completion is shown in UI

## Device Switching Behavior

### Unified Sidebar

- Shows all connected devices (Android + iOS)
- Displays device name and connection status
- Uses appropriate icons (phone for Android, iPhone for iOS)
- Connection status indicators (Ready, Locked, Disconnected)

### File Explorer

- Same UI for both device types
- Native glass window layout
- Instant hover effects
- Quick Look previews
- Background caching for instant folder switching
- Automatic backend selection based on path prefix:
  - `mtp://` → MTPService
  - `/` or `ios://` → iOSDeviceService

## AFC + HouseArrest Handling

### AFC (Apple File Conduit)

- Primary file access protocol for iOS devices
- Used for general file system operations
- Supports file listing, reading, writing, and deletion
- Integrated with libimobiledevice library

### HouseArrest

- Special protocol for accessing app sandboxes
- Allows access to documents and data of specific apps
- Implemented through `ios_house_arrest_start()` function
- Provides access to app-specific directories

## Caching Design

### iOSDeviceService Caching

- Folder listings cached for 30 seconds
- Cache keyed by path
- Automatic cache invalidation on device state changes
- Manual cache clearing available

### Transfer Caching

- Progress tracking with smooth updates
- Speed calculation with rolling average
- Time remaining estimation

## Unified Sidebar and Explorer Updates

### Sidebar Updates

- Dynamic device list based on connection status
- Real-time updates when devices connect/disconnect
- Device-specific icons and status indicators
- Connection state badges (Ready, Locked, Trust Needed)

### Explorer Updates

- Unified path display with device names
- Consistent navigation controls
- Same context menus for all file types
- Device-specific troubleshooting guides

## Error-Handling Rules

### Connection Errors

- **Trust Required**: Prompt user to tap "Trust This Computer"
- **Device Locked**: Prompt user to unlock device
- **Disconnected**: Show connection lost message
- **Generic Errors**: Provide detailed error information

### File Operation Errors

- **Access Denied**: Check file permissions
- **File Not Found**: Verify file path
- **IO Errors**: Retry operation or suggest alternative
- **Invalid Arguments**: Developer error handling

### Transfer Errors

- **Network Issues**: Retry with exponential backoff
- **Disk Full**: Show available space warning
- **Permission Errors**: Guide user to fix permissions

## Future iOS Feature Roadmap

### Short-term (Next Release)

1. App sandbox browsing with HouseArrest
2. Enhanced file metadata display
3. Improved error recovery mechanisms
4. Better progress reporting for large transfers

### Medium-term (Next 2-3 Releases)

1. iOS device information panel
2. File search within iOS devices
3. Batch operations for iOS files
4. Improved thumbnail generation for iOS media

### Long-term (Future Releases)

1. iOS device backup and restore functionality
2. App data management through HouseArrest
3. Integration with iOS document providers
4. Support for iOS wireless connections
5. Advanced file operations (compression, encryption)

## UX Behavior

### Connection States

- **Locked Device**: Show glowing banner "Unlock your iPhone to continue"
- **Trust Required**: Show glowing banner "Tap 'Trust This Computer' on your iPhone"
- **Auto-refresh**: Automatically refresh when device becomes ready
- **Non-blocking UI**: All operations are asynchronous

### Animations

- Match macOS 26 movement style
- Smooth transitions between views
- Liquid glass effects with proper material blending
- Zero-lag directory navigation

### Performance

- Background caching for instant folder switching
- Throttled progress updates to reduce UI overhead
- Efficient memory management for large file transfers
- Optimized rendering for smooth scrolling

## Technical Implementation Details

### Thread Safety

- All libimobiledevice operations on serial dispatch queue
- UI updates on main thread
- Proper memory management for C structures

### Memory Management

- Automatic cleanup of C strings and structures
- Weak references to prevent retain cycles
- Efficient cache invalidation

### Error Recovery

- Automatic reconnection attempts
- Graceful degradation when features unavailable
- Comprehensive logging for debugging

This integration maintains Lumen's Apple-like, native, glassy, elegant, zero-latency experience while extending support to iOS devices alongside existing Android support.
