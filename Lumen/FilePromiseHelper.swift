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
    
    init(item: FileSystemItem, fileService: FileService) {
        self.item = item
        self.fileService = fileService
        super.init()
    }
    
    func filePromiseProvider(_ filePromiseProvider: NSFilePromiseProvider, fileNameForType fileType: String) -> String {
        return item.name
    }
    
    func filePromiseProvider(_ filePromiseProvider: NSFilePromiseProvider, writePromiseTo url: URL, completionHandler: @escaping (Error?) -> Void) {
        // This is called when the user drops the file in Finder
        
        // We need to download the file from the device to the provided URL
        guard let mtpService = fileService as? MTPService else {
            completionHandler(NSError(domain: "FilePromiseHelper", code: 1, userInfo: [NSLocalizedDescriptionKey: "Invalid service type"]))
            return
        }
        
        Task {
            do {
                // The URL provided by Finder is the destination folder + filename
                // We need to download to this location
                
                // Note: MTPService.downloadFile takes a destination URL (including filename)
                try await mtpService.downloadFile(at: item.path, to: url, size: item.size) { progress, status in
                    // We could potentially report progress here if we had a way to hook into the drag progress
                    print("Drag download progress: \(Int(progress * 100))%")
                }
                
                completionHandler(nil)
            } catch {
                print("Error downloading dragged file: \(error)")
                completionHandler(error)
            }
        }
    }
}
