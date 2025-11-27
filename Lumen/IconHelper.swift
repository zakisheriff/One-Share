import AppKit
import SwiftUI

struct IconHelper {
    static func nativeIcon(for item: FileSystemItem) -> Image {
        // For remote files (MTP or iOS), use SF Symbols based on file type
        if item.path.hasPrefix("mtp://") || item.path.hasPrefix("ios://") {
            // Use SF Symbols for remote files
            return Image(systemName: item.type.iconName)
        } else {
            // Local file system – use the actual file path for native macOS icons
            let workspace = NSWorkspace.shared
            let url = URL(fileURLWithPath: item.path)
            let nsImage = workspace.icon(forFile: url.path)
            nsImage.size = NSSize(width: 128, height: 128) // Higher resolution for better quality
            return Image(nsImage: nsImage)
        }
    }
    
    // Get color for file type (for styling)
    static func colorForType(_ type: FileType) -> [Color] {
        switch type {
        case .folder:
            return [.blue, .blue.opacity(0.7)]
        case .image:
            return [.blue, .cyan]
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
}