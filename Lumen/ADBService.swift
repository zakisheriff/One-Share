//
//  ADBService.swift
//  Lumen
//
//  Created by Zaki Sheriff on 2025-11-25.
//

import Foundation

class ADBService: FileService {
    // Hardcoded path based on previous discovery. 
    // In a real app, this should be configurable or auto-detected.
    private let adbPath = "/Users/afraasheriff/Library/Android/sdk/platform-tools/adb"
    
    func listItems(at path: String) throws -> [FileSystemItem] {
        // Construct command: adb shell ls -l <path>
        // We use -d for the path itself to check existence, but here we want contents.
        // Actually, 'ls -l <path>' lists contents if it's a dir.
        // We need to handle spaces in path.
        let quotedPath = "'\(path)'"
        let output = try runADBCommand(["shell", "ls", "-l", quotedPath])
        
        return parseLSOutput(output, parentPath: path)
    }
    
    private func runADBCommand(_ arguments: [String]) throws -> String {
        let task = Process()
        task.executableURL = URL(fileURLWithPath: adbPath)
        task.arguments = arguments
        
        let pipe = Pipe()
        task.standardOutput = pipe
        task.standardError = pipe // Capture error too
        
        try task.run()
        task.waitUntilExit()
        
        let data = pipe.fileHandleForReading.readDataToEndOfFile()
        guard let output = String(data: data, encoding: .utf8) else {
            throw NSError(domain: "ADBService", code: 2, userInfo: [NSLocalizedDescriptionKey: "Failed to decode ADB output"])
        }
        
        if task.terminationStatus != 0 {
            // Check if it's just an empty directory or actual error
            // ls on empty dir might return nothing or specific message depending on implementation
            if output.contains("No such file or directory") {
                 throw NSError(domain: "ADBService", code: 3, userInfo: [NSLocalizedDescriptionKey: "Path not found: \(arguments.last ?? "")"])
            }
            // If it's just permission denied or other error
            if output.contains("Permission denied") {
                 throw NSError(domain: "ADBService", code: 4, userInfo: [NSLocalizedDescriptionKey: "Permission denied"])
            }
            
            // For now, treat non-zero as error unless we can prove otherwise
            // But sometimes ls returns non-zero for minor things. 
            // Let's log it but try to parse if there's output? 
            // Usually if status != 0, output is error message.
            throw NSError(domain: "ADBService", code: Int(task.terminationStatus), userInfo: [NSLocalizedDescriptionKey: "ADB Error: \(output)"])
        }
        
        return output
    }
    
    private func parseLSOutput(_ output: String, parentPath: String) -> [FileSystemItem] {
        var items: [FileSystemItem] = []
        let lines = output.components(separatedBy: .newlines)
        
        for line in lines {
            // Skip "total <number>" line
            if line.hasPrefix("total") { continue }
            if line.trimmingCharacters(in: .whitespaces).isEmpty { continue }
            
            // Expected format: drwxrwx--x 35 root sdcard_rw 4096 2023-01-01 12:00 foldername
            // We need to be careful about splitting because date/time formatting can vary
            // and filenames can have spaces.
            
            // Regex is safer.
            // This is a simplified regex for standard Android ls -l
            // Group 1: Permissions (d...)
            // Group 2: Size
            // Group 3: Date (YYYY-MM-DD)
            // Group 4: Time (HH:MM)
            // Group 5: Name (rest of line)
            
            // Note: Android ls -l output:
            // drwxrwx--x 4 root sdcard_rw 3452 2023-08-29 15:43 DCIM
            // -rw-rw---- 1 root sdcard_rw 1234 2023-08-29 15:43 file.txt
            
            // Columns: perms links owner group size date time name
            
            let parts = line.components(separatedBy: .whitespaces).filter { !$0.isEmpty }
            
            // We need at least 7 parts (perms, links, owner, group, size, date, time, name...)
            guard parts.count >= 8 else { continue }
            
            let perms = parts[0]
            // parts[1] is links
            // parts[2] is owner
            // parts[3] is group
            let sizeStr = parts[4]
            let dateStr = parts[5]
            let timeStr = parts[6]
            
            // Name is everything after time.
            // We need to find the index of timeStr in the parts and join the rest.
            // But parts doesn't preserve spaces in name.
            // Better: Reconstruct name from the original line.
            
            // Find the position of the time string in the line
            guard let timeRange = line.range(of: timeStr) else { continue }
            let nameStartIndex = timeRange.upperBound
            
            // There might be spaces between time and name
            let namePart = String(line[nameStartIndex...]).trimmingCharacters(in: .whitespaces)
            guard !namePart.isEmpty else { continue }
            
            if namePart == "." || namePart == ".." { continue }
            
            let isDirectory = perms.hasPrefix("d")
            let size = Int64(sizeStr) ?? 0
            
            // Date parsing
            let dateFormatter = DateFormatter()
            dateFormatter.dateFormat = "yyyy-MM-dd HH:mm"
            let modificationDate = dateFormatter.date(from: "\(dateStr) \(timeStr)") ?? Date()
            
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
            
            // Construct full path
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
        func downloadFile(at path: String, to localURL: URL) throws {
        // adb pull <remote> <local>
        let quotedRemotePath = "'\(path)'"
        let quotedLocalPath = "'\(localURL.path)'"
        _ = try runADBCommand(["pull", quotedRemotePath, quotedLocalPath])
    }
    
    func uploadFile(from localURL: URL, to path: String) throws {
        // adb push <local> <remote>
        let quotedLocalPath = "'\(localURL.path)'"
        let quotedRemotePath = "'\(path)'"
        _ = try runADBCommand(["push", quotedLocalPath, quotedRemotePath])
    }
}
}
