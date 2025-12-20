//
//  ADBService.swift
//  One Share
//
//  Created by Zaki Sheriff on 2025-11-25.
//

import Foundation

class ADBService: FileService {
    // Hardcoded path based on previous discovery. 
    // In a real app, this should be configurable or auto-detected.
    private let adbPath = "/Users/afraasheriff/Library/Android/sdk/platform-tools/adb"
    
    func listItems(at path: String) async throws -> [FileSystemItem] {
        return try await Task.detached(priority: .userInitiated) {
            // 1. Check if device is connected
            try self.checkDeviceConnection()
            
            // 2. Construct command: adb shell "ls -la <path>"
            // Ensure path ends with / to list contents of symlinks/dirs
            let listPath = path.hasSuffix("/") ? path : path + "/"
            
            // We wrap the path in single quotes for the shell command string
            // and pass the whole command as a single argument to "shell"
            // This avoids adb's argument parsing issues
            let shellCmd = "ls -la '\(listPath)'"
            
            let output = try self.runADBCommand(["shell", shellCmd])
            
            // DEBUG: Log output to file
            let debugLog = "Command: adb shell \(shellCmd)\nPath: \(path)\nOutput:\n\(output)\n"
            try? debugLog.write(to: URL(fileURLWithPath: "/Users/afraasheriff/Desktop/lumen_debug_ls.txt"), atomically: true, encoding: .utf8)
            
            return self.parseLSOutput(output, parentPath: path)
        }.value
    }
    
    // Helper to run ADB command synchronously (called from background task)
    nonisolated private func checkDeviceConnection() throws {
        let output = try runADBCommand(["devices"])
        let lines = output.components(separatedBy: .newlines)
        let hasDevice = lines.dropFirst().contains { line in
            let parts = line.components(separatedBy: .whitespaces).filter { !$0.isEmpty }
            return parts.count >= 2 && parts[1] == "device"
        }
        
        if !hasDevice {
            let isUnauthorized = lines.dropFirst().contains { $0.contains("unauthorized") }
            if isUnauthorized {
                 throw NSError(domain: "ADBService", code: 5, userInfo: [NSLocalizedDescriptionKey: "Device unauthorized. Check phone screen."])
            }
            let isOffline = lines.dropFirst().contains { $0.contains("offline") }
            if isOffline {
                 throw NSError(domain: "ADBService", code: 6, userInfo: [NSLocalizedDescriptionKey: "Device is offline. Try reconnecting USB."])
            }
            throw NSError(domain: "ADBService", code: 7, userInfo: [NSLocalizedDescriptionKey: "No Android device found."])
        }
    }
    
    func downloadFile(at path: String, to localURL: URL, size: Int64, progress: @escaping (Double, String) -> Void) async throws {
        // Immediate feedback
        progress(0.0, "Starting download...")
        
        let _ = try await Task.detached(priority: .userInitiated) {
            // Use -p flag for progress
            // adb pull -p <remote> <local>
            try self.runADBCommand(["pull", "-p", path, localURL.path]) { line in
                // Parse progress from output like: [ 45%] /path/to/file
                // ADB pull output format can vary, but often shows percentage
                // This is a simplified parser
                if let range = line.range(of: #"\d+%"#, options: .regularExpression) {
                    let percentStr = String(line[range]).dropLast()
                    if let percent = Double(percentStr) {
                        let sizeMB = Double(size) / 1024 / 1024
                        let downloadedMB = sizeMB * (percent / 100.0)
                        let status = String(format: "%.1f MB of %.1f MB", downloadedMB, sizeMB)
                        progress(percent / 100.0, status)
                    }
                } else {
                    // Fallback for non-progress lines
                    if !line.trimmingCharacters(in: .whitespaces).isEmpty {
                        // Check for "Transferring" or similar if needed, or just ignore
                    }
                }
            }
            
            // Ensure 100% at end
            progress(1.0, "Completed")
        }.value
    }
    
    func uploadFile(from localURL: URL, to path: String, progress: @escaping (Double, String) -> Void) async throws {
        // Immediate feedback
        progress(0.0, "Starting upload...")
        
        let _ = try await Task.detached(priority: .userInitiated) {
            // Use -p flag for progress
            // adb push -p <local> <remote>
            try self.runADBCommand(["push", "-p", localURL.path, path]) { line in
                if let percent = self.parseProgress(from: line) {
                    progress(percent, "Uploading...")
                }
            }
            // Ensure 100% at end
            progress(1.0, "Completed")
        }.value
    }
    
    nonisolated private func parseProgress(from line: String) -> Double? {
        if let range = line.range(of: "\\[\\s*(\\d+)%\\]", options: .regularExpression) {
             let matchString = line[range].components(separatedBy: CharacterSet.decimalDigits.inverted).joined()
             if let match = Double(matchString) {
                 return match / 100.0
             }
        }
        return nil
    }
    
    // Internal helper to handle both modes
    nonisolated private func runADBCommand(_ arguments: [String]) throws -> String {
        return try runADBCommand(arguments, progressHandler: nil)
    }

    // Actual implementation
    nonisolated private func runADBCommand(_ arguments: [String], progressHandler: ((String) -> Void)?) throws -> String {
        let task = Process()
        task.executableURL = URL(fileURLWithPath: adbPath)
        task.arguments = arguments
        
        let pipe = Pipe()
        task.standardOutput = pipe
        task.standardError = pipe
        
        let outputQueue = DispatchQueue(label: "com.lumen.adb.output")
        var fullOutput = ""
        let fullOutputLock = NSLock()
        
        if let handler = progressHandler {
            pipe.fileHandleForReading.readabilityHandler = { handle in
                let data = handle.availableData
                if !data.isEmpty, let str = String(data: data, encoding: .utf8) {
                    fullOutputLock.withLock {
                        fullOutput += str
                    }
                    let lines = str.components(separatedBy: CharacterSet(charactersIn: "\r\n"))
                    for line in lines where !line.isEmpty {
                        handler(line)
                    }
                }
            }
        } else {
            // If no progress handler, we still need to read the output to prevent blocking
            pipe.fileHandleForReading.readabilityHandler = { _ in }
        }
        
        try task.run()
        
        if progressHandler == nil {
             // Use the deadlock-free read
             let data = pipe.fileHandleForReading.readDataToEndOfFile()
             task.waitUntilExit()
             if let str = String(data: data, encoding: .utf8) {
                 fullOutput = str
             }
        } else {
            task.waitUntilExit()
            pipe.fileHandleForReading.readabilityHandler = nil
        }
        
        // Ensure the process is properly cleaned up
        task.terminate()
        
        // Close file handles
        pipe.fileHandleForReading.closeFile()
        
        if task.terminationStatus != 0 {
             // Access fullOutput safely
             let outputToCheck = outputQueue.sync { fullOutput }
             
             if outputToCheck.contains("No such file or directory") {
                 throw NSError(domain: "ADBService", code: 3, userInfo: [NSLocalizedDescriptionKey: "Path not found: \(arguments.last ?? "")"])
            }
            if outputToCheck.contains("Permission denied") {
                 throw NSError(domain: "ADBService", code: 4, userInfo: [NSLocalizedDescriptionKey: "Permission denied"])
            }
            throw NSError(domain: "ADBService", code: Int(task.terminationStatus), userInfo: [NSLocalizedDescriptionKey: "ADB Error: \(outputToCheck)"])
        }
        
        return outputQueue.sync { fullOutput }
    }
    
    nonisolated private func parseLSOutput(_ output: String, parentPath: String) -> [FileSystemItem] {
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
            // perms links owner group size [date parts...] name
            guard parts.count >= 7 else { continue }
            
            let perms = parts[0]
            // Basic validation of perms to ensure it's a file line
            guard perms.hasPrefix("d") || perms.hasPrefix("-") || perms.hasPrefix("l") else { continue }
            
            let isDirectory = perms.hasPrefix("d")
            
            // Size is usually at index 4
            let size = Int64(parts[4]) ?? 0
            
            // Date parsing strategy
            var modificationDate = Date()
            var nameStartIndex = 0
            
            // Try ISO format (YYYY-MM-DD HH:MM) -> parts[5], parts[6]
            if parts.count >= 8, let date = dateFormatterISO.date(from: "\(parts[5]) \(parts[6])") {
                modificationDate = date
                // Name starts after time string
                if let timeRange = line.range(of: parts[6], options: .backwards) {
                     nameStartIndex = timeRange.upperBound.utf16Offset(in: line)
                }
            }
            // Try Short format (MMM dd HH:MM) -> parts[5], parts[6], parts[7]
            else if parts.count >= 9, let date = dateFormatterShort.date(from: "\(parts[5]) \(parts[6]) \(parts[7])") {
                // Fix year
                var components = Calendar.current.dateComponents([.year, .month, .day, .hour, .minute], from: date)
                components.year = Calendar.current.component(.year, from: Date())
                modificationDate = Calendar.current.date(from: components) ?? date
                
                if let timeRange = line.range(of: parts[7], options: .backwards) {
                     nameStartIndex = timeRange.upperBound.utf16Offset(in: line)
                }
            }
            // Try Year format (MMM dd yyyy) -> parts[5], parts[6], parts[7]
            else if parts.count >= 9, let date = dateFormatterYear.date(from: "\(parts[5]) \(parts[6]) \(parts[7])") {
                modificationDate = date
                if let timeRange = line.range(of: parts[7], options: .backwards) {
                     nameStartIndex = timeRange.upperBound.utf16Offset(in: line)
                }
            }
            // Fallback: Assume name is the last part (risky for spaces) or everything after 7th token
            else {
                if parts.count >= 8 {
                    // Assume parts[7] is the start of the name?
                    // Reconstruct name from parts[7...]
                    // This loses spaces between name parts if we just join.
                    // But we can try to find the substring in the line.
                    let searchStart = parts[6] // Time or Year
                    if let range = line.range(of: searchStart, options: .backwards) {
                        nameStartIndex = range.upperBound.utf16Offset(in: line)
                    } else {
                        // Desperation: just take the last part
                        // items.append(...)
                        // continue
                    }
                }
            }
            
            // Extract name
            var namePart = ""
            if nameStartIndex > 0 && nameStartIndex < line.count {
                let index = line.index(line.startIndex, offsetBy: nameStartIndex)
                namePart = String(line[index...]).trimmingCharacters(in: .whitespaces)
            } else {
                // Fallback if index logic failed but we have parts
                if parts.count > 7 {
                    namePart = parts.suffix(from: 7).joined(separator: " ")
                }
            }
            
            guard !namePart.isEmpty else { continue }
            if namePart == "." || namePart == ".." { continue }
            
            // Handle Symlinks (l...) -> name -> target
            // ls -l output: lrwxrwxrwx ... name -> target
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
    
    func deleteItem(at path: String) async throws {
        let _ = try await Task.detached(priority: .userInitiated) {
            // 1. Check if device is connected
            try self.checkDeviceConnection()
            
            // 2. Construct command: adb shell "rm -r <path>"
            let shellCmd = "rm -r '\(path)'"
            
            let output = try self.runADBCommand(["shell", shellCmd])
            
            // DEBUG: Log output to file
            let debugLog = "Command: adb shell \(shellCmd)\nPath: \(path)\nOutput:\n\(output)\n"
            try? debugLog.write(to: URL(fileURLWithPath: "/Users/afraasheriff/Desktop/lumen_debug_rm.txt"), atomically: true, encoding: .utf8)
        }.value
    }
}
