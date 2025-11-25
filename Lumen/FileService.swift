//
//  FileService.swift
//  Lumen
//
//  Created by Zaki Sheriff on 2025-11-25.
//

import Foundation

protocol FileService {
    func listItems(at path: String) throws -> [FileSystemItem]
    func downloadFile(at path: String, to localURL: URL) throws
    func uploadFile(from localURL: URL, to path: String) throws
}

class MockFileService: FileService {
    let mockItems: [FileSystemItem]
    
    init(items: [FileSystemItem]) {
        self.mockItems = items
    }
    
    func listItems(at path: String) throws -> [FileSystemItem] {
        return mockItems
    }
}
