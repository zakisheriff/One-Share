//
//  LocalFileService.swift
//  Lumen
//
//  Created by Zaki Sheriff on 2025-11-25.
//

import Foundation
import AppKit

class LocalFileService: FileService {
    private let fileManager = FileManager.default
    
    func listItems(at path: String) throws -> [FileSystemItem] {
        let url = URL(fileURLWithPath: path)
        print("DEBUG: Listing items at \(path)")
        
        // Basic error handling/checking
        var isDir: ObjCBool = false
        guard fileManager.fileExists(atPath: path, isDirectory: &isDir) else {
            print("DEBUG: Path does not exist: \(path)")
            return []
        }
        guard isDir.boolValue else {
            print("DEBUG: Path is not a directory: \(path)")
            return []
        }
        
        // Check readability
        if !fileManager.isReadableFile(atPath: path) {
            print("DEBUG: Path is not readable: \(path)")
            throw NSError(domain: "LocalFileService", code: 1, userInfo: [NSLocalizedDescriptionKey: "Permission denied for path: \(path)"])
        }
        
        let resourceKeys: [URLResourceKey] = [.nameKey, .fileSizeKey, .isDirectoryKey, .contentModificationDateKey, .contentTypeKey]
        
        let urls = try fileManager.contentsOfDirectory(at: url, includingPropertiesForKeys: resourceKeys, options: [.skipsHiddenFiles])
        print("DEBUG: Found \(urls.count) items at \(path)")
        
        return urls.compactMap { url -> FileSystemItem? in
            do {
                let resourceValues = try url.resourceValues(forKeys: Set(resourceKeys))
                let name = resourceValues.name ?? url.lastPathComponent
                let size = Int64(resourceValues.fileSize ?? 0)
                let isDirectory = resourceValues.isDirectory ?? false
                let modificationDate = resourceValues.contentModificationDate ?? Date()
                
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
                    modificationDate: modificationDate
                )
            } catch {
                print("DEBUG: Failed to get resource values for \(url.path): \(error)")
                return nil
            }
        }
    }
}
