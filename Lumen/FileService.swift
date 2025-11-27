//
//  FileService.swift
//  Lumen
//
//  Created by Zaki Sheriff on 2025-11-25.
//

import Foundation

enum ConnectionState: String, Equatable {
    case disconnected
    case connecting
    case connected
    case connectedLocked // Connected but screen locked/no permission
    case error
}

protocol FileService {
    func listItems(at path: String) async throws -> [FileSystemItem]
    func downloadFile(at path: String, to localURL: URL, size: Int64, progress: @escaping (Double, String) -> Void) async throws
    func uploadFile(from localURL: URL, to path: String, progress: @escaping (Double, String) -> Void) async throws
    func deleteItem(at path: String) async throws
}

class MockFileService: FileService {
    let mockItems: [FileSystemItem]
    
    init(items: [FileSystemItem]) {
        self.mockItems = items
    }
    
    func listItems(at path: String) async throws -> [FileSystemItem] {
        return mockItems
    }
    
    func downloadFile(at path: String, to localURL: URL, size: Int64, progress: @escaping (Double, String) -> Void) async throws {
        print("Mock download from \(path) to \(localURL)")
        progress(0.5, "Downloading...")
        try await Task.sleep(nanoseconds: 1_000_000_000)
        progress(1.0, "Done")
    }
    
    func uploadFile(from localURL: URL, to path: String, progress: @escaping (Double, String) -> Void) async throws {
        print("Mock upload from \(localURL) to \(path)")
        progress(0.5, "Uploading...")
        try await Task.sleep(nanoseconds: 1_000_000_000)
        progress(1.0, "Done")
    }
    
    func deleteItem(at path: String) async throws {
        print("Mock delete item at \(path)")
        // Simulate some work
        try await Task.sleep(nanoseconds: 500_000_000)
    }
}