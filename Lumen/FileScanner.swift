//
//  FileScanner.swift
//  Lumen
//
//  Created by Zaki Sheriff on 2025-11-25.
//

import Foundation
import Combine
import SwiftUI

struct FileMetadata: Codable, Identifiable, Hashable {
    var id: String { path }
    let name: String
    let path: String
    let size: Int64
    let modificationDate: Date
    let type: FileType
    let isRemote: Bool
    
    var description: String {
        return "File: \(name), Path: \(path), Size: \(ByteCountFormatter.string(fromByteCount: size, countStyle: .file)), Date: \(modificationDate.formatted())"
    }
}

class FileScanner: ObservableObject {
    @Published var isScanning = false
    @Published var indexedFiles: [FileMetadata] = []
    @Published var scanProgress: Double = 0.0
    
    let localService = LocalFileService()
    let mtpService: MTPService
    
    init(mtpService: MTPService) {
        self.mtpService = mtpService
    }
    
    func startScan() {
        guard !isScanning else { return }
        isScanning = true
        indexedFiles.removeAll()
        scanProgress = 0.0
        
        Task {
            // Scan in parallel
            await withTaskGroup(of: Void.self) { group in
                group.addTask { await self.scanLocalFiles() }
                group.addTask { await self.scanRemoteFiles() }
            }
            
            await MainActor.run {
                self.isScanning = false
                print("Scan complete. Indexed \(self.indexedFiles.count) files.")
            }
        }
    }
    
    private func scanLocalFiles() async {
        let dirsToScan = [
            FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first,
            FileManager.default.urls(for: .downloadsDirectory, in: .userDomainMask).first,
            FileManager.default.urls(for: .picturesDirectory, in: .userDomainMask).first,
            FileManager.default.urls(for: .musicDirectory, in: .userDomainMask).first,
            FileManager.default.urls(for: .moviesDirectory, in: .userDomainMask).first
        ].compactMap { $0 }
        
        for dir in dirsToScan {
            await recursiveLocalScan(at: dir)
        }
    }
    
    private func recursiveLocalScan(at url: URL) async {
        let enumerator = FileManager.default.enumerator(at: url, includingPropertiesForKeys: [.nameKey, .fileSizeKey, .contentModificationDateKey, .isDirectoryKey], options: [.skipsHiddenFiles, .skipsPackageDescendants])
        
        var batch: [FileMetadata] = []
        
        while let fileURL = enumerator?.nextObject() as? URL {
            // Check for cancellation
            if Task.isCancelled { return }
            
            do {
                let resources = try fileURL.resourceValues(forKeys: [.nameKey, .fileSizeKey, .contentModificationDateKey, .isDirectoryKey])
                
                if let isDir = resources.isDirectory, !isDir {
                    let name = resources.name ?? fileURL.lastPathComponent
                    let size = Int64(resources.fileSize ?? 0)
                    let date = resources.contentModificationDate ?? Date()
                    let type = getFileType(for: name)
                    
                    let metadata = FileMetadata(name: name, path: fileURL.path, size: size, modificationDate: date, type: type, isRemote: false)
                    batch.append(metadata)
                    
                    // Update UI every 50 files to keep it responsive but not spam the main thread
                    if batch.count >= 50 {
                        let batchCopy = batch
                        await MainActor.run {
                            self.indexedFiles.append(contentsOf: batchCopy)
                        }
                        batch.removeAll()
                    }
                }
            } catch {
                continue
            }
        }
        
        // Append remaining
        if !batch.isEmpty {
            let batchCopy = batch
            await MainActor.run {
                self.indexedFiles.append(contentsOf: batchCopy)
            }
        }
    }
    
    private func scanRemoteFiles() async {
        // Scan MTP root recursively
        await recursiveMTPScan(at: "mtp://")
    }
    
    private func recursiveMTPScan(at path: String) async {
        do {
            let items = try await mtpService.listItems(at: path)
            
            var batch: [FileMetadata] = []
            
            for item in items {
                if item.isDirectory {
                    // Recursive call
                    // Limit depth or specific folders for performance
                    if ["DCIM", "Pictures", "Download", "Music", "Movies"].contains(item.name) || path != "mtp://" {
                         await recursiveMTPScan(at: item.path)
                    }
                } else {
                    let metadata = FileMetadata(name: item.name, path: item.path, size: item.size, modificationDate: item.modificationDate, type: item.type, isRemote: true)
                    batch.append(metadata)
                }
            }
            
            if !batch.isEmpty {
                let batchCopy = batch
                await MainActor.run {
                    self.indexedFiles.append(contentsOf: batchCopy)
                }
            }
            
        } catch {
            print("Error scanning MTP path \(path): \(error)")
        }
    }
    
    private func getFileType(for fileName: String) -> FileType {
        let ext = (fileName as NSString).pathExtension.lowercased()
        switch ext {
        case "jpg", "jpeg", "png", "gif", "bmp", "tiff", "webp": return .image
        case "mp4", "mov", "avi", "mkv", "wmv", "flv", "webm": return .video
        case "mp3", "wav", "aac", "flac", "ogg", "m4a": return .audio
        case "pdf", "doc", "docx", "txt", "rtf", "pages", "epub": return .document
        case "zip", "rar", "7z", "tar", "gz": return .archive
        default: return .file
        }
    }
}
