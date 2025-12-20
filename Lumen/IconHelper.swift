//
//  IconHelper.swift
//  One Share
//
//  Created by Zaki Sheriff on 2025-11-25.
//

import AppKit
import SwiftUI
import UniformTypeIdentifiers

// MARK: - Icon Caching for Performance
final class IconCache {
    static let shared = IconCache()
    
    private let nativeIconCache = NSCache<NSString, NSImage>()
    private let sfSymbolCache = NSCache<NSString, NSImage>()
    
    private init() {
        // Configure cache limits
        nativeIconCache.countLimit = 500
        sfSymbolCache.countLimit = 200
    }
    
    func getNativeIcon(for extension: String, isDirectory: Bool) -> NSImage? {
        let key = "\(isDirectory ? "dir" : `extension`)" as NSString
        return nativeIconCache.object(forKey: key)
    }
    
    func setNativeIcon(_ image: NSImage, for extension: String, isDirectory: Bool) {
        let key = "\(isDirectory ? "dir" : `extension`)" as NSString
        nativeIconCache.setObject(image, forKey: key)
    }
    
    func getSFSymbol(for key: String) -> NSImage? {
        return sfSymbolCache.object(forKey: key as NSString)
    }
    
    func setSFSymbol(_ image: NSImage, for key: String) {
        sfSymbolCache.setObject(image, forKey: key as NSString)
    }
    
    func clearCache() {
        nativeIconCache.removeAllObjects()
        sfSymbolCache.removeAllObjects()
    }
}

struct IconHelper {
    // MARK: - Native macOS Icons (for local files) - CACHED
    static func nativeIcon(for item: FileSystemItem) -> Image {
        let ext = (item.path as NSString).pathExtension.lowercased()
        
        // Check cache first
        if let cachedImage = IconCache.shared.getNativeIcon(for: ext, isDirectory: item.isDirectory) {
            return Image(nsImage: cachedImage)
        }
        
        // Generate and cache
        let workspace = NSWorkspace.shared
        let nsImage: NSImage
        
        if item.isDirectory {
             nsImage = workspace.icon(for: .folder)
        } else {
            if let type = UTType(filenameExtension: ext) {
                nsImage = workspace.icon(for: type)
            } else {
                nsImage = workspace.icon(for: .data)
            }
        }
        
        nsImage.size = NSSize(width: 128, height: 128)
        IconCache.shared.setNativeIcon(nsImage, for: ext, isDirectory: item.isDirectory)
        
        return Image(nsImage: nsImage)
    }
    
    // MARK: - SF Symbol Icons (for remote files - Android/iOS) - CACHED
    static func sfSymbolIcon(for item: FileSystemItem) -> Image {
        let symbolName = sfSymbolName(for: item)
        return Image(systemName: symbolName)
    }
    
    // Get the appropriate SF Symbol name based on file type/extension
    static func sfSymbolName(for item: FileSystemItem) -> String {
        if item.isDirectory {
            return "folder.fill"
        }
        
        let ext = (item.name as NSString).pathExtension.lowercased()
        
        // Images
        if ["jpg", "jpeg", "png", "gif", "heic", "heif", "webp", "bmp", "tiff", "tif", "ico", "svg", "raw", "cr2", "nef", "arw"].contains(ext) {
            return "photo.fill"
        }
        
        // Videos
        if ["mp4", "mov", "m4v", "avi", "mkv", "webm", "wmv", "flv", "3gp", "mpeg", "mpg", "ts", "mts", "vob"].contains(ext) {
            return "play.rectangle.fill"
        }
        
        // Audio
        if ["mp3", "m4a", "wav", "aac", "flac", "ogg", "wma", "aiff", "alac", "opus", "mid", "midi"].contains(ext) {
            return "waveform.circle.fill"
        }
        
        // PDF
        if ext == "pdf" {
            return "doc.text.fill"
        }
        
        // Documents
        if ["doc", "docx", "txt", "rtf", "pages", "odt", "tex", "md", "markdown"].contains(ext) {
            return "doc.text.fill"
        }
        
        // Spreadsheets
        if ["xlsx", "xls", "csv", "numbers", "ods"].contains(ext) {
            return "tablecells.fill"
        }
        
        // Presentations
        if ["ppt", "pptx", "key", "odp"].contains(ext) {
            return "rectangle.stack.fill"
        }
        
        // Archives
        if ["zip", "rar", "7z", "tar", "gz", "bz2", "xz", "tgz", "tbz2", "dmg", "iso"].contains(ext) {
            return "archivebox.fill"
        }
        
        // Code files
        if ["swift", "py", "js", "ts", "json", "html", "css", "xml", "java", "kt", "cpp", "c", "h", "hpp", "rs", "go", "rb", "php", "sh", "bash", "zsh", "yaml", "yml", "toml", "ini", "conf", "config"].contains(ext) {
            return "chevron.left.forwardslash.chevron.right"
        }
        
        // Database files
        if ["db", "sqlite", "sqlite3", "sql", "mdb", "accdb"].contains(ext) {
            return "cylinder.fill"
        }
        
        // Font files
        if ["ttf", "otf", "woff", "woff2", "eot"].contains(ext) {
            return "textformat"
        }
        
        // eBooks
        if ["epub", "mobi", "azw", "azw3", "fb2"].contains(ext) {
            return "book.fill"
        }
        
        // APK/IPA (App packages)
        if ["apk", "ipa", "app", "exe", "msi", "pkg"].contains(ext) {
            return "app.fill"
        }
        
        // Log files
        if ["log"].contains(ext) {
            return "text.alignleft"
        }
        
        // Contact files
        if ["vcf", "vcard"].contains(ext) {
            return "person.crop.rectangle.fill"
        }
        
        // Calendar files
        if ["ics", "ical"].contains(ext) {
            return "calendar"
        }
        
        // Default for unknown types
        return "doc.fill"
    }
    
    // MARK: - Color Helpers
    
    // Get color for file type (for styling)
    static func colorForType(_ type: FileType) -> [Color] {
        switch type {
        case .folder:
            return [.blue, .blue.opacity(0.7)]
        case .image:
            return [.cyan, .blue]
        case .video:
            return [.purple, .pink]
        case .audio:
            return [.orange, .red]
        case .document:
            return [.blue, .indigo]
        case .archive:
            return [.yellow, .orange]
        default:
            return [.gray, .gray.opacity(0.7)]
        }
    }
    
    // Get accent color for SF Symbol icons based on file extension - CACHED lookup table
    private static let extensionColorMap: [String: Color] = {
        var map: [String: Color] = [:]
        
        // Images - Cyan
        for ext in ["jpg", "jpeg", "png", "gif", "heic", "heif", "webp", "bmp", "tiff", "tif", "ico", "svg", "raw", "cr2", "nef", "arw"] {
            map[ext] = .cyan
        }
        
        // Videos - Purple
        for ext in ["mp4", "mov", "m4v", "avi", "mkv", "webm", "wmv", "flv", "3gp", "mpeg", "mpg", "ts", "mts", "vob"] {
            map[ext] = .purple
        }
        
        // Audio - Orange
        for ext in ["mp3", "m4a", "wav", "aac", "flac", "ogg", "wma", "aiff", "alac", "opus", "mid", "midi"] {
            map[ext] = .orange
        }
        
        // PDF - Red
        map["pdf"] = .red
        
        // Documents - Blue
        for ext in ["doc", "docx", "txt", "rtf", "pages", "odt", "tex", "md", "markdown"] {
            map[ext] = .blue
        }
        
        // Spreadsheets - Green
        for ext in ["xlsx", "xls", "csv", "numbers", "ods"] {
            map[ext] = .green
        }
        
        // Presentations - Orange
        for ext in ["ppt", "pptx", "key", "odp"] {
            map[ext] = .orange
        }
        
        // Archives - Yellow
        for ext in ["zip", "rar", "7z", "tar", "gz", "bz2", "xz", "tgz", "tbz2", "dmg", "iso"] {
            map[ext] = .yellow
        }
        
        // Code - Mint
        for ext in ["swift", "py", "js", "ts", "json", "html", "css", "xml", "java", "kt", "cpp", "c", "h", "hpp", "rs", "go", "rb", "php", "sh", "bash", "zsh", "yaml", "yml", "toml", "ini", "conf", "config"] {
            map[ext] = .mint
        }
        
        // APK/IPA - Teal
        for ext in ["apk", "ipa", "app", "exe", "msi", "pkg"] {
            map[ext] = .teal
        }
        
        return map
    }()
    
    static func iconColor(for item: FileSystemItem) -> Color {
        if item.isDirectory {
            return .blue
        }
        
        let ext = (item.name as NSString).pathExtension.lowercased()
        return extensionColorMap[ext] ?? .secondary
    }
}