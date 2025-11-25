import Foundation

enum FileType {
    case folder, file, image, video, audio, document, archive
}

struct FileSystemItem {
    let name: String
    let path: String
    let size: Int64
    let type: FileType
    let modificationDate: Date
}

func parseLSOutput(_ output: String, parentPath: String) -> [FileSystemItem] {
    var items: [FileSystemItem] = []
    let lines = output.components(separatedBy: .newlines)
    
    let dateFormatterISO = DateFormatter()
    dateFormatterISO.dateFormat = "yyyy-MM-dd HH:mm"
    
    let dateFormatterShort = DateFormatter()
    dateFormatterShort.dateFormat = "MMM dd HH:mm" // e.g. Jan 01 12:00
    
    let dateFormatterYear = DateFormatter()
    dateFormatterYear.dateFormat = "MMM dd yyyy" // e.g. Jan 01 2023
    
    for line in lines {
        // Skip "total <number>" line
        if line.hasPrefix("total") { continue }
        if line.trimmingCharacters(in: .whitespaces).isEmpty { continue }
        
        let parts = line.components(separatedBy: .whitespaces).filter { !$0.isEmpty }
        
        // We need at least 7 parts to have a chance at metadata
        guard parts.count >= 7 else { continue }
        
        let perms = parts[0]
        guard perms.hasPrefix("d") || perms.hasPrefix("-") || perms.hasPrefix("l") else { continue }
        
        let isDirectory = perms.hasPrefix("d")
        
        let size = Int64(parts[4]) ?? 0
        
        var modificationDate = Date()
        var nameStartIndex = 0
        
        if parts.count >= 8, let date = dateFormatterISO.date(from: "\(parts[5]) \(parts[6])") {
            modificationDate = date
            if let timeRange = line.range(of: parts[6], options: .backwards) {
                 nameStartIndex = timeRange.upperBound.utf16Offset(in: line)
            }
        }
        else if parts.count >= 9, let date = dateFormatterShort.date(from: "\(parts[5]) \(parts[6]) \(parts[7])") {
            var components = Calendar.current.dateComponents([.year, .month, .day, .hour, .minute], from: date)
            components.year = Calendar.current.component(.year, from: Date())
            modificationDate = Calendar.current.date(from: components) ?? date
            
            if let timeRange = line.range(of: parts[7], options: .backwards) {
                 nameStartIndex = timeRange.upperBound.utf16Offset(in: line)
            }
        }
        else if parts.count >= 9, let date = dateFormatterYear.date(from: "\(parts[5]) \(parts[6]) \(parts[7])") {
            modificationDate = date
            if let timeRange = line.range(of: parts[7], options: .backwards) {
                 nameStartIndex = timeRange.upperBound.utf16Offset(in: line)
            }
        }
        else {
            if parts.count >= 8 {
                let searchStart = parts[6]
                if let range = line.range(of: searchStart, options: .backwards) {
                    nameStartIndex = range.upperBound.utf16Offset(in: line)
                }
            }
        }
        
        var namePart = ""
        if nameStartIndex > 0 && nameStartIndex < line.count {
            let index = line.index(line.startIndex, offsetBy: nameStartIndex)
            namePart = String(line[index...]).trimmingCharacters(in: .whitespaces)
        } else {
            if parts.count > 7 {
                namePart = parts.suffix(from: 7).joined(separator: " ")
            }
        }
        
        guard !namePart.isEmpty else { continue }
        if namePart == "." || namePart == ".." { continue }
        
        if perms.hasPrefix("l") {
            if let arrowRange = namePart.range(of: " -> ") {
                namePart = String(namePart[..<arrowRange.lowerBound])
            }
        }
        
        let type: FileType
        if isDirectory {
            type = .folder
        } else {
            let ext = (namePart as NSString).pathExtension.lowercased()
            switch ext {
            case "jpg", "jpeg", "png", "heic", "gif": type = .image
            case "mp4", "mov", "mkv", "avi": type = .video
            case "mp3", "wav", "m4a": type = .audio
            case "pdf", "doc", "docx", "txt", "md": type = .document
            case "zip", "rar", "7z", "tar": type = .archive
            default: type = .file
            }
        }
        
        let itemPath = parentPath.hasSuffix("/") ? "\(parentPath)\(namePart)" : "\(parentPath)/\(namePart)"
        
        items.append(FileSystemItem(
            name: namePart,
            path: itemPath,
            size: size,
            type: type,
            modificationDate: modificationDate
        ))
    }
    
    return items
}

let output = """
-rwxrwx--- 1 u0_a307 media_rw  113621922 2025-06-07 15:18 cricket-league mod apk 1.26.0.apk
-rwxrwx--- 1 u0_a307 media_rw      58768 2025-06-06 15:20 cursed-Goofy-Ahh-Images-meme_12.jpg
-rwxrwx--- 1 u0_a307 media_rw       2115 2025-06-22 22:27 cw_template.py
drwxrws--- 3 u0_a307 media_rw       3452 2025-10-21 14:05 galvan-ben-10
-rw-rw---- 1 u0_a307 media_rw     235888 1970-01-01 05:30 resources.arsc
"""

let items = parseLSOutput(output, parentPath: "/sdcard/Download")
print("Found \(items.count) items")
for item in items {
    print("- \(item.name) (\(item.size))")
}
