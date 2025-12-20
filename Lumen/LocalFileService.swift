//
//  LocalFileService.swift
//  One Share
//
//  Created by Zaki Sheriff on 2025-11-25.
//

import Foundation
import AppKit

class LocalFileService: FileService {
    private let fileManager = FileManager.default
    
    func listItems(at path: String) async throws -> [FileSystemItem] {
        let url = URL(fileURLWithPath: path)
        print("DEBUG: Listing items at \(path)")
        
        // Basic error handling/checking
        var isDir: ObjCBool = false
        guard fileManager.fileExists(atPath: path, isDirectory: &isDir) else {
            print("❌ DEBUG: Path does not exist: \(path)")
            throw NSError(domain: "LocalFileService", code: 404, userInfo: [NSLocalizedDescriptionKey: "Path does not exist: \(path)"])
        }
        guard isDir.boolValue else {
            print("❌ DEBUG: Path is not a directory: \(path)")
            throw NSError(domain: "LocalFileService", code: 400, userInfo: [NSLocalizedDescriptionKey: "Path is not a directory: \(path)"])
        }
        
        // Check readability
        if !fileManager.isReadableFile(atPath: path) {
            print("DEBUG: Path is not readable: \(path)")
            throw NSError(domain: "LocalFileService", code: 1, userInfo: [NSLocalizedDescriptionKey: "Permission denied for path: \(path)"])
        }
        
        let resourceKeys: [URLResourceKey] = [.nameKey, .fileSizeKey, .isDirectoryKey, .contentModificationDateKey, .creationDateKey, .contentTypeKey]
        
        // Run on background thread to avoid blocking even for local files
        return try await Task.detached(priority: .userInitiated) {
            let urls = try FileManager.default.contentsOfDirectory(at: url, includingPropertiesForKeys: resourceKeys, options: [.skipsHiddenFiles])
            print("DEBUG: Found \(urls.count) items at \(path)")
            
            return urls.compactMap { url -> FileSystemItem? in
                do {
                    let resourceValues = try url.resourceValues(forKeys: Set(resourceKeys))
                    let name = resourceValues.name ?? url.lastPathComponent
                    let size = Int64(resourceValues.fileSize ?? 0)
                    let isDirectory = resourceValues.isDirectory ?? false
                    let modificationDate = resourceValues.contentModificationDate ?? Date()
                    let creationDate = resourceValues.creationDate ?? Date()
                    
                    let type: FileType
                    if isDirectory {
                        type = .folder
                    } else {
                        let ext = url.pathExtension.lowercased()
                        switch ext {
                        case "jpg", "jpeg", "png", "heic", "gif": type = .image
                        case "mp4", "mov", "mkv", "avi": type = .video
                        case "mp3", "wav", "m4a": type = .audio
                        case "pdf", "doc", "docx", "txt", "md": type = .document
                        case "zip", "rar", "7z", "tar": type = .archive
                        default: type = .file
                        }
                    }
                    
                    return FileSystemItem(
                        name: name,
                        path: url.path,
                        size: size,
                        type: type,
                        modificationDate: modificationDate,
                        creationDate: creationDate
                    )
                } catch {
                    print("DEBUG: Failed to get resource values for \(url.path): \(error)")
                    return nil
                }
            }
        }.value
    }
    
    func downloadFile(at path: String, to localURL: URL, size: Int64, progress: @escaping (Double, String) -> Void) async throws {
        // For local service, "download" is just a copy with progress tracking
        let sourceURL = URL(fileURLWithPath: path)
        try await copyFileWithProgress(from: sourceURL, to: localURL, totalSize: size, progress: progress)
    }
    
    func uploadFile(from localURL: URL, to path: String, progress: @escaping (Double, String) -> Void) async throws {
        // For local service, "upload" is just a copy with progress tracking
        let destURL = URL(fileURLWithPath: path).appendingPathComponent(localURL.lastPathComponent)
        
        // Get file size
        let attributes = try fileManager.attributesOfItem(atPath: localURL.path)
        let fileSize = attributes[.size] as? Int64 ?? 0
        
        try await copyFileWithProgress(from: localURL, to: destURL, totalSize: fileSize, progress: progress)
    }
    
    // Helper function to copy files with progress tracking
    private func copyFileWithProgress(from sourceURL: URL, to destURL: URL, totalSize: Int64, progress: @escaping (Double, String) -> Void) async throws {
        progress(0, "Preparing...")
        
        // For small files (< 10MB), just copy directly
        if totalSize < 10_485_760 {
            try fileManager.copyItem(at: sourceURL, to: destURL)
            progress(1.0, "Completed")
            return
        }
        
        // For larger files, copy in chunks to show progress
        let chunkSize = 1_048_576 // 1MB chunks
        
        guard let inputStream = InputStream(url: sourceURL) else {
            throw NSError(domain: "LocalFileService", code: 2, userInfo: [NSLocalizedDescriptionKey: "Cannot open source file"])
        }
        
        guard let outputStream = OutputStream(url: destURL, append: false) else {
            throw NSError(domain: "LocalFileService", code: 3, userInfo: [NSLocalizedDescriptionKey: "Cannot create destination file"])
        }
        
        inputStream.open()
        outputStream.open()
        
        defer {
            inputStream.close()
            outputStream.close()
        }
        
        var buffer = [UInt8](repeating: 0, count: chunkSize)
        var totalBytesWritten: Int64 = 0
        let startTime = Date()
        
        while inputStream.hasBytesAvailable {
            let bytesRead = inputStream.read(&buffer, maxLength: chunkSize)
            
            if bytesRead < 0 {
                throw inputStream.streamError ?? NSError(domain: "LocalFileService", code: 4, userInfo: [NSLocalizedDescriptionKey: "Read error"])
            }
            
            if bytesRead == 0 {
                break
            }
            
            let bytesWritten = outputStream.write(buffer, maxLength: bytesRead)
            
            if bytesWritten < 0 {
                throw outputStream.streamError ?? NSError(domain: "LocalFileService", code: 5, userInfo: [NSLocalizedDescriptionKey: "Write error"])
            }
            
            totalBytesWritten += Int64(bytesWritten)
            
            // Calculate progress
            let progressValue = Double(totalBytesWritten) / Double(totalSize)
            
            // Calculate speed
            let elapsed = Date().timeIntervalSince(startTime)
            let speed = elapsed > 0 ? Double(totalBytesWritten) / elapsed : 0
            let speedMBps = speed / (1024 * 1024)
            
            // Calculate remaining time
            let remainingBytes = totalSize - totalBytesWritten
            let remainingTime = speed > 0 ? Double(remainingBytes) / speed : 0
            
            let statusMessage = String(format: "Copying %.1f MB/s - %@ remaining", 
                                     speedMBps,
                                     formatTimeRemaining(seconds: remainingTime))
            
            progress(progressValue, statusMessage)
            
            // Small delay to prevent UI overload
            try await Task.sleep(nanoseconds: 10_000_000) // 10ms
        }
        
        progress(1.0, "Completed")
    }
    
    private func formatTimeRemaining(seconds: Double) -> String {
        if seconds < 1 {
            return "< 1s"
        } else if seconds < 60 {
            return String(format: "%.0fs", seconds)
        } else if seconds < 3600 {
            let minutes = Int(seconds / 60)
            let secs = Int(seconds.truncatingRemainder(dividingBy: 60))
            return "\(minutes)m \(secs)s"
        } else {
            let hours = Int(seconds / 3600)
            let minutes = Int((seconds.truncatingRemainder(dividingBy: 3600)) / 60)
            return "\(hours)h \(minutes)m"
        }
    }

    
    func deleteItem(at path: String) async throws {
        let url = URL(fileURLWithPath: path)
        try fileManager.removeItem(at: url)
    }
}
