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
        case .image: return "photo"
        case .video: return "film"
        case .audio: return "waveform"
        case .document: return "doc.text"
        case .archive: return "archivebox"
        }
    }
}

struct FileSystemItem: Identifiable, Hashable, Codable, Comparable {
    var id = UUID()
    var name: String
    var path: String
    var size: Int64
    var type: FileType
    var modificationDate: Date
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
