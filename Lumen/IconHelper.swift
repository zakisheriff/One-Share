import AppKit
import SwiftUI

struct IconHelper {
    static func nativeIcon(for item: FileSystemItem) -> Image {
        let workspace = NSWorkspace.shared
        // If the path is an MTP URL, derive icon from file extension
        if item.path.hasPrefix("mtp://") {
            // Extract file extension from name
            let ext = (item.name as NSString).pathExtension.lowercased()
            if ext.isEmpty {
                // Use generic folder or file icon based on type
                return Image(nsImage: workspace.icon(forFileType: item.type == .folder ? "folder" : "public.item"))
            } else {
                // Use system icon for the specific file type
                return Image(nsImage: workspace.icon(forFileType: ext))
            }
        } else {
            // Local file system – use the actual file path
            let url = URL(fileURLWithPath: item.path)
            let nsImage = workspace.icon(forFile: url.path)
            nsImage.size = NSSize(width: 64, height: 64)
            return Image(nsImage: nsImage)
        }
    }
}
