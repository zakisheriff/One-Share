//
//  iOSDeviceService.swift
//  One Share
//
//  Created by [Your Name] on 2025-11-27.
//

import Foundation
import Combine

class iOSDeviceService: FileService, ObservableObject, @unchecked Sendable {
    
    // Serial queue for thread safety with libimobiledevice which is not thread-safe
    private let queue = DispatchQueue(label: "com.oneshare.ios.queue", qos: .userInitiated)
    
    // Cache for folder listings
    private struct CacheEntry {
        let items: [FileSystemItem]
        let timestamp: Date
    }
    private var listingCache: [String: CacheEntry] = [:]
    private let cacheTimeout: TimeInterval = 300 // Cache for 5 minutes
    
    // Device monitoring
    @Published var connectionState: ConnectionState = .disconnected
    private var deviceMonitoringTimer: Timer?
    var onDeviceConnectionChange: ((ConnectionState) -> Void)?
    
    // Device info
    private var deviceInfo: iOSDeviceInfo?
    
    init() {
        print("iOSDeviceService init")
        queue.async {
            self.log("Attempting initial connection...")
            let success = ios_connect()
            self.log("Initial connection result: \(success)")
        }
        
        // Start monitoring for device connections
        startDeviceMonitoring()
    }
    
    // Add a method to get device name
    func getDeviceName() -> String {
        guard ios_is_connected() else { return "iOS Device" }
        
        if let cName = ios_get_device_name() {
            let name = String(cString: cName)
            free(cName) // Free the C string allocated by ios_get_device_name
            return name.isEmpty ? "iOS Device" : name
        }
        
        return "iOS Device"
    }
    
    private func log(_ message: String) {
        let logMessage = "\(Date()): \(message)\n"
        if let data = logMessage.data(using: .utf8) {
            let url = URL(fileURLWithPath: "/Users/afraasheriff/Desktop/lumen_ios_debug.txt")
            if FileManager.default.fileExists(atPath: url.path) {
                if let handle = try? FileHandle(forWritingTo: url) {
                    handle.seekToEndOfFile()
                    handle.write(data)
                    handle.closeFile()
                }
            } else {
                try? data.write(to: url)
            }
        }
    }
    
    deinit {
        stopDeviceMonitoring()
        ios_disconnect()
    }
    
    // Device monitoring functions
    private func startDeviceMonitoring() {
        deviceMonitoringTimer = Timer.scheduledTimer(withTimeInterval: 1.0, repeats: true) { _ in
            self.checkDeviceConnection()
        }
    }
    
    private func stopDeviceMonitoring() {
        deviceMonitoringTimer?.invalidate()
        deviceMonitoringTimer = nil
    }
    
    private func checkDeviceConnection() {
        queue.async {
            var currentState: ConnectionState = .disconnected
            
            let deviceState = ios_get_device_state()
            
            switch deviceState {
            case IOS_DEVICE_DISCONNECTED:
                currentState = .disconnected
            case IOS_DEVICE_CONNECTING:
                currentState = .connecting
            case IOS_DEVICE_CONNECTED:
                currentState = .connected
            case IOS_DEVICE_TRUST_REQUIRED:
                currentState = .connectedLocked
            case IOS_DEVICE_LOCKED:
                currentState = .connectedLocked
            case IOS_DEVICE_ERROR:
                currentState = .error
            default:
                currentState = .disconnected
            }
            
            // If connection state changed, notify
            if currentState != self.connectionState {
                self.log("iOS Connection state changed: \(self.connectionState) -> \(currentState)")
                DispatchQueue.main.async {
                    self.connectionState = currentState
                    self.onDeviceConnectionChange?(currentState)
                    
                    // If we're now connected, get device info
                    if currentState == .connected {
                        self.refreshDeviceInfo()
                    }
                }
            }
            
            // If we're connected but our cache is empty, try to refresh
            if currentState == .connected && self.listingCache.isEmpty {
                // Force a refresh when device is first detected
                self.listingCache.removeAll()
            }
        }
    }
    
    private func refreshDeviceInfo() {
        queue.async {
            let info = ios_get_device_info()
            DispatchQueue.main.async {
                self.deviceInfo = info
            }
        }
    }
    
    // Public method to clear cache
    func clearCache() {
        queue.async {
            self.listingCache.removeAll()
        }
    }
    
    private func getFileType(for fileName: String, isDirectory: Bool) -> FileType {
        if isDirectory {
            return .folder
        }
        
        let ext = (fileName as NSString).pathExtension.lowercased()
        switch ext {
        case "jpg", "jpeg", "png", "gif", "bmp", "tiff", "webp":
            return .image
        case "mp4", "mov", "avi", "mkv", "wmv", "flv", "webm":
            return .video
        case "mp3", "wav", "aac", "flac", "ogg", "m4a":
            return .audio
        case "pdf", "doc", "docx", "txt", "rtf", "pages", "epub":
            return .document
        case "zip", "rar", "7z", "tar", "gz":
            return .archive
        default:
            return .file
        }
    }
    
    func listItems(at path: String) async throws -> [FileSystemItem] {
        log("listItems called for path: \(path)")
        
        // Normalize iOS path - convert ios:// or / to actual root path
        var normalizedPath = path
        if path == "ios://" || path == "ios:///" || path.isEmpty || (path == "/" && ios_is_connected()) {
            normalizedPath = "/"
            log("listItems: Normalized path to root: /")
        } else if path.hasPrefix("ios://") {
            normalizedPath = path.replacingOccurrences(of: "ios://", with: "")
            if normalizedPath.isEmpty {
                normalizedPath = "/"
            }
            log("listItems: Normalized iOS path to: \(normalizedPath)")
        }
        
        // Check cache first
        if let cached = listingCache[normalizedPath] {
            let age = Date().timeIntervalSince(cached.timestamp)
            if age < cacheTimeout {
                log("listItems: Returning cached result (\(cached.items.count) items, age: \(age)s)")
                return cached.items
            } else {
                log("listItems: Cache expired (age: \(age)s)")
            }
        }
        
        return try await withCheckedThrowingContinuation { continuation in
            queue.async {
                self.log("listItems: queue block started")
                guard ios_connect() else {
                    self.log("listItems: Connection failed")
                    let deviceState = ios_get_device_state()
                    let errorMessage: String
                    switch deviceState {
                    case IOS_DEVICE_TRUST_REQUIRED:
                        errorMessage = """
                        Trust Required
                        
                        Please unlock your iPhone/iPad and tap "Trust" when prompted.
                        
                        If you don't see the prompt:
                        1. Disconnect and reconnect the USB cable
                        2. Make sure your device is unlocked
                        3. Look for the "Trust This Computer?" dialog
                        """
                    case IOS_DEVICE_LOCKED:
                        errorMessage = """
                        Device Locked
                        
                        Please unlock your iPhone/iPad with your passcode or Face ID.
                        
                        After unlocking:
                        • The device should automatically connect
                        • You'll see your photos in the /DCIM folder
                        """
                    case IOS_DEVICE_DISCONNECTED:
                        errorMessage = """
                        iOS Device Not Connected
                        
                        To connect your iPhone/iPad:
                        1. Connect your device with a USB cable
                        2. Unlock your device
                        3. Tap "Trust" when prompted
                        4. Wait a moment for the connection
                        
                        Note: You'll only see Camera Roll photos (/DCIM), Books, Downloads, and Recordings.
                        Full filesystem access requires jailbreak.
                        """
                    case IOS_DEVICE_ERROR:
                        errorMessage = """
                        Connection Error
                        
                        Please try:
                        1. Disconnect and reconnect the USB cable
                        2. Try a different USB port
                        3. Restart One Share
                        4. Restart your iOS device
                        
                        Make sure you've trusted this computer on your device.
                        """
                    default:
                        errorMessage = """
                        Could Not Connect
                        
                        Please ensure:
                        • Your iOS device is connected via USB
                        • Your device is unlocked
                        • You've tapped "Trust" on your device
                        
                        Available folders: /DCIM (photos), /Books, /Downloads, /Recordings
                        """
                    }
                    continuation.resume(throwing: NSError(domain: "iOSDeviceService", code: 1, userInfo: [NSLocalizedDescriptionKey: errorMessage]))
                    return
                }
                
                var count: Int32 = 0
                let filesPtr = ios_list_files(normalizedPath, &count)
                self.log("listItems: ios_list_files returned count: \(count)")
                
                var items: [FileSystemItem] = []
                
                if count > 0, let files = filesPtr {
                    let buffer = UnsafeBufferPointer(start: files, count: Int(count))
                    
                    for file in buffer {
                        let nameStr = withUnsafePointer(to: file.name) { ptr in
                            return ptr.withMemoryRebound(to: CChar.self, capacity: 256) { charPtr in
                                return String(cString: charPtr)
                            }
                        }
                        
                        // Skip "." and ".." entries
                        if nameStr == "." || nameStr == ".." {
                            continue
                        }
                        
                        // Determine file type based on extension
                        let fileType = self.getFileType(for: nameStr, isDirectory: file.is_directory)
                        
                        // Build proper path
                        var itemPath: String
                        if normalizedPath == "/" {
                            itemPath = "/" + nameStr
                        } else {
                            itemPath = normalizedPath + (normalizedPath.hasSuffix("/") ? "" : "/") + nameStr
                        }
                        
                        let item = FileSystemItem(
                            name: nameStr,
                            path: itemPath,
                            size: Int64(file.size),
                            type: fileType,
                            modificationDate: Date(timeIntervalSince1970: TimeInterval(file.modification_date)),
                            creationDate: Date(timeIntervalSince1970: TimeInterval(file.modification_date))
                        )
                        items.append(item)
                    }
                    
                    ios_free_files(files)
                }
                
                // Cache the results
                self.listingCache[normalizedPath] = CacheEntry(items: items, timestamp: Date())
                
                self.log("listItems: Returning \(items.count) items")
                continuation.resume(returning: items)
            }
        }
    }
    
    func downloadFile(at path: String, to localURL: URL, size: Int64, progress: @escaping (Double, String) -> Void) async throws {
        try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<Void, Error>) in
            queue.async {
                guard ios_connect() else {
                    continuation.resume(throwing: NSError(domain: "iOSDeviceService", code: 1, userInfo: [NSLocalizedDescriptionKey: "Device not connected"]))
                    return
                }
                
                let context = iOSProgressContext(progress: progress, totalSize: Double(size))
                let contextPtr = Unmanaged.passRetained(context).toOpaque()
                
                let callback: iOSProgressCallback = { sent, total, ctx in
                    guard let ctx = ctx else { return }
                    let context = Unmanaged<iOSProgressContext>.fromOpaque(ctx).takeUnretainedValue()
                    
                    let percentage = Double(sent) / context.totalSize
                    let status = "Downloading \(ByteCountFormatter.string(fromByteCount: Int64(sent), countStyle: .file)) / \(ByteCountFormatter.string(fromByteCount: Int64(total), countStyle: .file))"
                    
                    DispatchQueue.main.async {
                        context.progress(percentage, status)
                    }
                }
                
                let ret = ios_download_file(path, localURL.path, callback, contextPtr)
                
                Unmanaged<iOSProgressContext>.fromOpaque(contextPtr).release()
                
                if ret == 0 {
                    continuation.resume()
                } else {
                    continuation.resume(throwing: NSError(domain: "iOSDeviceService", code: Int(ret), userInfo: nil))
                }
            }
        }
    }
    
    func downloadFolder(at path: String, to localURL: URL, progress: @escaping (Double, String) -> Void) async throws {
        // Create the local directory
        try FileManager.default.createDirectory(at: localURL, withIntermediateDirectories: true, attributes: nil)
        
        // List items in the folder
        let items = try await listItems(at: path)
        
        let totalItems = Double(items.count)
        var processedItems = 0.0
        
        for item in items {
            let itemLocalURL = localURL.appendingPathComponent(item.name)
            
            if item.isDirectory {
                try await downloadFolder(at: item.path, to: itemLocalURL) { p, s in
                    // Propagate progress? For now just update main status
                    let overallProgress = (processedItems + p) / totalItems
                    progress(overallProgress, "Downloading \(item.name)...")
                }
            } else {
                try await downloadFile(at: item.path, to: itemLocalURL, size: item.size) { p, s in
                    let overallProgress = (processedItems + p) / totalItems
                    progress(overallProgress, "Downloading \(item.name)...")
                }
            }
            
            processedItems += 1.0
            progress(processedItems / totalItems, "Downloaded \(item.name)")
        }
    }
    
    func uploadFile(from localURL: URL, to path: String, progress: @escaping (Double, String) -> Void) async throws {
        let filename = localURL.lastPathComponent
        let destinationPath = path + (path.hasSuffix("/") ? "" : "/") + filename
        let fileSize = (try? FileManager.default.attributesOfItem(atPath: localURL.path)[.size] as? UInt64) ?? 0
        
        try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<Void, Error>) in
            queue.async {
                guard ios_connect() else {
                    continuation.resume(throwing: NSError(domain: "iOSDeviceService", code: 1, userInfo: [NSLocalizedDescriptionKey: "Device not connected"]))
                    return
                }
                
                let context = iOSProgressContext(progress: progress, totalSize: Double(fileSize))
                let contextPtr = Unmanaged.passRetained(context).toOpaque()
                
                let callback: iOSProgressCallback = { sent, total, ctx in
                    guard let ctx = ctx else { return }
                    let context = Unmanaged<iOSProgressContext>.fromOpaque(ctx).takeUnretainedValue()
                    
                    let percentage = Double(sent) / context.totalSize
                    let status = "Uploading \(ByteCountFormatter.string(fromByteCount: Int64(sent), countStyle: .file)) / \(ByteCountFormatter.string(fromByteCount: Int64(total), countStyle: .file))"
                    
                    DispatchQueue.main.async {
                        context.progress(percentage, status)
                    }
                }
                
                let ret = ios_upload_file(localURL.path, destinationPath, callback, contextPtr)
                
                Unmanaged<iOSProgressContext>.fromOpaque(contextPtr).release()
                
                if ret == 0 {
                    continuation.resume()
                } else {
                    continuation.resume(throwing: NSError(domain: "iOSDeviceService", code: Int(ret), userInfo: nil))
                }
            }
        }
    }
    
    func deleteItem(at path: String) async throws {
        try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<Void, Error>) in
            queue.async {
                guard ios_connect() else {
                    continuation.resume(throwing: NSError(domain: "iOSDeviceService", code: 1, userInfo: [NSLocalizedDescriptionKey: "Device not connected"]))
                    return
                }
                
                let ret = ios_delete_file(path)
                
                if ret == 0 {
                    continuation.resume()
                } else {
                    continuation.resume(throwing: NSError(domain: "iOSDeviceService", code: Int(ret), userInfo: nil))
                }
            }
        }
    }
    
    // House Arrest functions for app sandbox access
    func startHouseArrest(for bundleId: String) async throws {
        try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<Void, Error>) in
            queue.async {
                guard ios_connect() else {
                    continuation.resume(throwing: NSError(domain: "iOSDeviceService", code: 1, userInfo: [NSLocalizedDescriptionKey: "Device not connected"]))
                    return
                }
                
                let success = ios_house_arrest_start(bundleId)
                
                if success {
                    continuation.resume()
                } else {
                    continuation.resume(throwing: NSError(domain: "iOSDeviceService", code: 2, userInfo: [NSLocalizedDescriptionKey: "Failed to start House Arrest for app \(bundleId)"]))
                }
            }
        }
    }
    
    func stopHouseArrest() {
        queue.async {
            ios_house_arrest_stop()
        }
    }
    
    func getAppContainers() async throws -> [String] {
        // For now, we'll return a placeholder - in a real implementation,
        // we would query the device for installed apps
        return [
            "com.apple.MobileSMS",
            "com.apple.camera",
            "com.apple.mobilesafari",
            "com.apple.Music"
        ]
    }
}

class iOSProgressContext {
    let progress: (Double, String) -> Void
    let totalSize: Double
    
    init(progress: @escaping (Double, String) -> Void, totalSize: Double) {
        self.progress = progress
        self.totalSize = totalSize
    }
}