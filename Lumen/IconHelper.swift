import AppKit
import SwiftUI

struct IconHelper {
    static func nativeIcon(for item: FileSystemItem) -> Image {
        // If the path is an MTP URL, use the file type to determine the icon
        if item.path.hasPrefix("mtp://") {
            // Use SF Symbols based on the file type
            return Image(systemName: item.type.iconName)
        } else {
            // Local file system – use the actual file path
            let workspace = NSWorkspace.shared
            let url = URL(fileURLWithPath: item.path)
            let nsImage = workspace.icon(forFile: url.path)
            nsImage.size = NSSize(width: 64, height: 64)
            return Image(nsImage: nsImage)
        }
    }
}