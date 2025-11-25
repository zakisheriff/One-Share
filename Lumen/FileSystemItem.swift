//
//  FileSystemItem.swift
//  Lumen
//
//  Created by Zaki Sheriff on 2025-11-25.
//

import Foundation
import SwiftUI

enum FileType: String, Codable {
    case folder
    case file
    case image
    case video
    case audio
    case document
    case archive
    
    var iconName: String {
        switch self {
        case .folder: return "folder.fill"
        case .file: return "doc"
        case .image: return "photo.fill"
        case .video: return "film.fill"
        case .audio: return "waveform.circle.fill"
        case .document: return "doc.text.fill"
        case .archive: return "archivebox.fill"
        }
    }
}

struct FileSystemItem: Identifiable, Hashable, Codable, Comparable, Sendable {
    var id = UUID()
    var name: String
    var path: String
    var size: Int64
    var type: FileType
    var modificationDate: Date
    var creationDate: Date = Date() // Default to current date if not provided
    
    var isDirectory: Bool {
        return type == .folder
    }
    
    var formattedSize: String {
        if isDirectory { return "--" }
        return ByteCountFormatter.string(fromByteCount: size, countStyle: .file)
    }
    
    var formattedDate: String {
        let formatter = DateFormatter()
        formatter.dateStyle = .medium
        formatter.timeStyle = .short
        return formatter.string(from: modificationDate)
    }
    
    static func < (lhs: FileSystemItem, rhs: FileSystemItem) -> Bool {
        return lhs.name.localizedStandardCompare(rhs.name) == .orderedAscending
    }
}