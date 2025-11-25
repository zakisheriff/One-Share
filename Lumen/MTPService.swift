//
//  MTPService.swift
//  Lumen
//
//  Created by Zaki Sheriff on 2025-11-25.
//

import Foundation

class MTPService: FileService {
    
    // Serial queue for thread safety with libmtp which is not thread-safe
    private let queue = DispatchQueue(label: "com.lumen.mtp.queue", qos: .userInitiated)
    
    // Cache for folder listings
    private struct CacheEntry {
        let items: [FileSystemItem]
        let timestamp: Date
    }
    private var listingCache: [String: CacheEntry] = [:]
    private let cacheTimeout: TimeInterval = 30 // Cache for 30 seconds
    
    // Device monitoring
    private var deviceMonitoringTimer: Timer?
    private var lastConnectionState: Bool = false
    var onDeviceConnectionChange: ((Bool) -> Void)?
    
    init() {
        log("MTPService init")
        queue.async {
            self.log("Attempting initial connection...")
            let success = mtp_connect()
            self.log("Initial connection result: \(success)")
        }
        
        // Start monitoring for device connections
        startDeviceMonitoring()
    }
    
    private func log(_ message: String) {
        let logMessage = "\(Date()): \(message)\n"
        if let data = logMessage.data(using: .utf8) {
            let url = URL(fileURLWithPath: "/Users/afraasheriff/Desktop/lumen_mtp_debug.txt")
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
        // We can't easily dispatch in deinit, but we should try to clean up.
        // Since queue holds self strongly in blocks, deinit only happens when no blocks are pending?
        // Actually, deinit is tricky with async.
        // Let's just call disconnect synchronously or hope OS cleans up.
        // Ideally we have an explicit disconnect method.
        mtp_disconnect()
    }
    
    // Device monitoring functions
    private func startDeviceMonitoring() {
        deviceMonitoringTimer = Timer.scheduledTimer(withTimeInterval: 2.0, repeats: true) { _ in
            self.checkDeviceConnection()
        }
    }
    
    private func stopDeviceMonitoring() {
        deviceMonitoringTimer?.invalidate()
        deviceMonitoringTimer = nil
    }
    
    private func checkDeviceConnection() {
        queue.async {
            let isConnected = mtp_is_connected()
            
            // If connection state changed, notify
            if isConnected != self.lastConnectionState {
                self.lastConnectionState = isConnected
                DispatchQueue.main.async {
                    self.onDeviceConnectionChange?(isConnected)
                }
            }
            
            // If we're connected but our cache is empty, try to refresh
            if isConnected && self.listingCache.isEmpty {
                // Force a refresh when device is first detected
                self.listingCache.removeAll()
            }
        }
    }
    
    // Public method to clear cache
    func clearCache() {
        queue.async {
            self.listingCache.removeAll()
        }
    }

    private func parsePath(_ path: String) -> (UInt32, UInt32) {
        // Format: mtp://storageId/parentId/childId/...
        // We only care about the LAST component for the file/folder ID.
        // And the FIRST component for storage ID.
        
        if path == "/" || path == "mtp://" || path.isEmpty {
            return (0, 0xFFFFFFFF)
        }
        
        // Remove scheme
        let cleanPath = path.replacingOccurrences(of: "mtp://", with: "")
        let components = cleanPath.split(separator: "/")
        
        if components.isEmpty {
             return (0, 0xFFFFFFFF)
        }
        
        let storageId = UInt32(components[0]) ?? 0
        
        if components.count == 1 {
            // Only storage ID provided, implies root of that storage
            return (storageId, 0xFFFFFFFF)
        }
        
        // The last component is the ID of the target item
        if let last = components.last, let id = UInt32(last) {
            return (storageId, id)
        }
        
        return (storageId, 0xFFFFFFFF)
    }
    
    private func getFileType(for fileName: String, isFolder: Bool) -> FileType {
        if isFolder {
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
        let (storageId, parentId) = parsePath(path)
        log("listItems called for path: \(path) (Storage: \(storageId), Parent: \(parentId))")
        
        // Check cache first
        if let cached = listingCache[path] {
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
                guard mtp_connect() else {
                    self.log("listItems: Connection failed")
                    continuation.resume(throwing: NSError(domain: "MTPService", code: 1, userInfo: [NSLocalizedDescriptionKey: "Could not connect. Close 'Android File Transfer' or 'Preview' and try again."]))
                    return
                }
                
                self.log("listItems: Calling mtp_list_files")
                var count: Int32 = 0
                let filesPtr = mtp_list_files(storageId, parentId, &count)
                self.log("listItems: mtp_list_files returned count: \(count)")
                
                var items: [FileSystemItem] = []
                
                if count > 0, let files = filesPtr {
                    let buffer = UnsafeBufferPointer(start: files, count: Int(count))
                    
                    for file in buffer {
                        let nameStr = withUnsafePointer(to: file.name) { ptr in
                            return ptr.withMemoryRebound(to: CChar.self, capacity: 256) { charPtr in
                                return String(cString: charPtr)
                            }
                        }
                        
                        // Determine file type based on extension
                        let fileType = self.getFileType(for: nameStr, isFolder: file.is_folder)
                        
                        // Construct hierarchical path: currentPath + "/" + fileID
                        // Ensure no double slashes
                        let separator = path.hasSuffix("/") ? "" : "/"
                        let itemPath = "\(path)\(separator)\(file.id)"
                        
                        let finalPath: String
                        // Only use the simple storageId/fileId format for actual root paths
                        if path == "mtp://" || path == "/" || path.isEmpty { // Handle root
                             finalPath = "mtp://\(file.storage_id)/\(file.id)"
                        } else {
                             finalPath = itemPath
                        }
                        
                        let item = FileSystemItem(
                            name: nameStr,
                            path: finalPath,
                            size: Int64(file.size),
                            type: fileType, // Use the determined file type instead of always .file
                            modificationDate: Date(),
                            creationDate: Date() // MTP doesn't provide creation date, so we use current date
                        )
                        items.append(item)
                    }
                    
                    mtp_free_files(files)
                }
                
                // Cache the results
                self.listingCache[path] = CacheEntry(items: items, timestamp: Date())
                
                self.log("listItems: Returning \(items.count) items")
                continuation.resume(returning: items)
            }
        }
    }
    
    func downloadFile(at path: String, to localURL: URL, size: Int64, progress: @escaping (Double, String) -> Void) async throws {
        let (_, fileId) = parsePath(path)
        
        try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<Void, Error>) in
            queue.async {
                guard mtp_connect() else {
                    continuation.resume(throwing: NSError(domain: "MTPService", code: 1, userInfo: [NSLocalizedDescriptionKey: "Device not connected"]))
                    return
                }
                
                let context = ProgressContext(progress: progress, totalSize: Double(size))
                let contextPtr = Unmanaged.passRetained(context).toOpaque()
                
                let callback: MTPProgressCallback = { sent, total, ctx in
                    guard let ctx = ctx else { return }
                    let context = Unmanaged<ProgressContext>.fromOpaque(ctx).takeUnretainedValue()
                    
                    let percentage = Double(sent) / context.totalSize
                    let status = "Downloading \(ByteCountFormatter.string(fromByteCount: Int64(sent), countStyle: .file)) / \(ByteCountFormatter.string(fromByteCount: Int64(total), countStyle: .file))"
                    
                    DispatchQueue.main.async {
                        context.progress(percentage, status)
                    }
                }
                
                let ret = mtp_download_file(fileId, localURL.path, callback, contextPtr)
                
                Unmanaged<ProgressContext>.fromOpaque(contextPtr).release()
                
                if ret == 0 {
                    continuation.resume()
                } else {
                    continuation.resume(throwing: NSError(domain: "MTPService", code: Int(ret), userInfo: nil))
                }
            }
        }
    }
    
    func uploadFile(from localURL: URL, to path: String, progress: @escaping (Double, String) -> Void) async throws {
        let (storageId, parentId) = parsePath(path)
        let filename = localURL.lastPathComponent
        let fileSize = (try? FileManager.default.attributesOfItem(atPath: localURL.path)[.size] as? UInt64) ?? 0
        
        try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<Void, Error>) in
            queue.async {
                guard mtp_connect() else {
                    continuation.resume(throwing: NSError(domain: "MTPService", code: 1, userInfo: [NSLocalizedDescriptionKey: "Device not connected"]))
                    return
                }
                
                let context = ProgressContext(progress: progress, totalSize: Double(fileSize))
                let contextPtr = Unmanaged.passRetained(context).toOpaque()
                
                let callback: MTPProgressCallback = { sent, total, ctx in
                    guard let ctx = ctx else { return }
                    let context = Unmanaged<ProgressContext>.fromOpaque(ctx).takeUnretainedValue()
                    
                    let percentage = Double(sent) / context.totalSize
                    let status = "Uploading \(ByteCountFormatter.string(fromByteCount: Int64(sent), countStyle: .file)) / \(ByteCountFormatter.string(fromByteCount: Int64(total), countStyle: .file))"
                    
                    DispatchQueue.main.async {
                        context.progress(percentage, status)
                    }
                }
                
                let ret = mtp_upload_file(localURL.path, storageId, parentId, filename, fileSize, callback, contextPtr)
                
                Unmanaged<ProgressContext>.fromOpaque(contextPtr).release()
                
                if ret == 0 {
                    continuation.resume()
                } else {
                    continuation.resume(throwing: NSError(domain: "MTPService", code: Int(ret), userInfo: nil))
                }
            }
        }
    }
    
    func deleteItem(at path: String) async throws {
        let (_, fileId) = parsePath(path)
        
        try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<Void, Error>) in
            queue.async {
                guard mtp_connect() else {
                    continuation.resume(throwing: NSError(domain: "MTPService", code: 1, userInfo: [NSLocalizedDescriptionKey: "Device not connected"]))
                    return
                }
                
                let ret = mtp_delete_file(fileId)
                
                if ret == 0 {
                    continuation.resume()
                } else {
                    continuation.resume(throwing: NSError(domain: "MTPService", code: Int(ret), userInfo: nil))
                }
            }
        }
    }
}

class ProgressContext {
    let progress: (Double, String) -> Void
    let totalSize: Double
    
    init(progress: @escaping (Double, String) -> Void, totalSize: Double) {
        self.progress = progress
        self.totalSize = totalSize
    }
}
