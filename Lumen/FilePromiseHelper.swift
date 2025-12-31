//
//  FilePromiseHelper.swift
//  One Share
//
//  Created by Zaki Sheriff on 2025-11-25.
//

import AppKit
import UniformTypeIdentifiers

class FilePromiseHelper: NSObject, NSFilePromiseProviderDelegate {
    
    let item: FileSystemItem
    let fileService: FileService
    
    // Keep a strong reference to prevent deallocation during async download
    private static var activeHelpers: [FilePromiseHelper] = []
    
    init(item: FileSystemItem, fileService: FileService) {
        self.item = item
        self.fileService = fileService
        super.init()
        // Add self to active helpers to prevent deallocation
        FilePromiseHelper.activeHelpers.append(self)
    }
    
    func filePromiseProvider(_ filePromiseProvider: NSFilePromiseProvider, fileNameForType fileType: String) -> String {
        return item.name
    }
    
    func filePromiseProvider(_ filePromiseProvider: NSFilePromiseProvider, writePromiseTo url: URL, completionHandler: @escaping (Error?) -> Void) {
        // This is called when the user drops the file in Finder
        print("🔍 FilePromise: Writing file \(item.name) to \(url.path)")
        
        Task {
            do {
                if let mtpService = fileService as? MTPService {
                    // Android MTP download
                    try await mtpService.downloadFile(at: item.path, to: url, size: item.size) { progress, status in
                        print("🔍 FilePromise: Drag download progress: \(Int(progress * 100))%")
                    }
                } else if let iosService = fileService as? iOSDeviceService {
                    // iOS download
                    try await iosService.downloadFile(at: item.path, to: url, size: item.size) { progress, status in
                        print("🔍 FilePromise: Drag download progress: \(Int(progress * 100))%")
                    }
                } else if fileService is LocalFileService {
                    // Local file - just copy it
                    let sourceURL = URL(fileURLWithPath: item.path)
                    try FileManager.default.copyItem(at: sourceURL, to: url)
                    print("🔍 FilePromise: Copied local file to \(url.path)")
                } else {
                    throw NSError(domain: "FilePromiseHelper", code: 1, userInfo: [NSLocalizedDescriptionKey: "Unsupported file service"])
                }
                
                completionHandler(nil)
                
                // Remove from active helpers after completion
                await MainActor.run {
                    FilePromiseHelper.activeHelpers.removeAll { $0 === self }
                }
            } catch {
                print("🔍 FilePromise: Error downloading dragged file: \(error)")
                completionHandler(error)
                
                // Remove from active helpers after error
                await MainActor.run {
                    FilePromiseHelper.activeHelpers.removeAll { $0 === self }
                }
            }
        }
    }
    
    // Get the appropriate UTType for the file
    static func utType(for item: FileSystemItem) -> UTType {
        if item.isDirectory {
            return .folder
        }
        
        let ext = (item.name as NSString).pathExtension.lowercased()
        if let utType = UTType(filenameExtension: ext) {
            return utType
        }
        
        return .data
    }
}
