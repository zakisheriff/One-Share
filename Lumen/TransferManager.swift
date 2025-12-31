//
//  TransferManager.swift
//  One Share
//
//  Created by Zaki Sheriff on 2025-11-25.
//

import Foundation
import SwiftUI
import Combine

@MainActor
class TransferManager: ObservableObject {
    @Published var isTransferring = false
    @Published var progress: Double = 0
    @Published var status: String = ""
    @Published var filename: String = ""
    @Published var transferSpeed: String = ""
    @Published var timeRemaining: String = ""
    @Published var totalSize: Int64 = 0
    @Published var bytesTransferred: Int64 = 0
    
    private var currentTask: Task<Void, any Error>?
    private var transferStartTime: Date?
    private var lastUpdateTime: Date?
    private var lastBytesTransferred: Int64 = 0
    private var speedSamples: [Double] = [] // Rolling window for smooth speed calculation
    private let maxSpeedSamples = 10 // Keep last 10 samples
    
    func startTransfer(item: ClipboardItem, to destService: FileService, at destPath: String) {
        guard !isTransferring else { return }
        guard !item.items.isEmpty else { return }
        
        isTransferring = true
        filename = item.items.count == 1 ? item.items[0].name : "\(item.items.count) files"
        progress = 0
        status = "Preparing..."
        transferSpeed = ""
        timeRemaining = ""
        transferStartTime = Date()
        lastUpdateTime = Date()
        lastBytesTransferred = 0
        speedSamples = []
        
        currentTask = Task {
            do {
                // Small delay to ensure UI shows "Preparing..."
                try await Task.sleep(nanoseconds: 100_000_000) // 0.1s
                
                // Calculate total size
                let totalSize = item.items.reduce(0) { $0 + $1.size }
                var totalBytesProcessed: Int64 = 0
                
                for fileItem in item.items {
                    // Determine transfer type
                    if item.sourceService is LocalFileService && destService is MTPService {
                        // Mac -> Android (Upload)
                        let sourceURL = URL(fileURLWithPath: fileItem.path)
                        try await destService.uploadFile(from: sourceURL, to: destPath) { [weak self] fileProgress, status in
                            Task { @MainActor in
                                let currentFileBytes = Int64(Double(fileItem.size) * fileProgress)
                                let totalProgress = Double(totalBytesProcessed + currentFileBytes) / Double(totalSize > 0 ? totalSize : 1)
                                self?.updateProgress(progress: totalProgress, status: "Uploading \(fileItem.name)...", totalSize: totalSize)
                            }
                        }
                    } else if item.sourceService is MTPService && destService is LocalFileService {
                        // Android -> Mac (Download)
                        let destURL = URL(fileURLWithPath: destPath).appendingPathComponent(fileItem.name)
                        try await item.sourceService.downloadFile(at: fileItem.path, to: destURL, size: fileItem.size) { [weak self] fileProgress, status in
                            Task { @MainActor in
                                let currentFileBytes = Int64(Double(fileItem.size) * fileProgress)
                                let totalProgress = Double(totalBytesProcessed + currentFileBytes) / Double(totalSize > 0 ? totalSize : 1)
                                self?.updateProgress(progress: totalProgress, status: "Downloading \(fileItem.name)...", totalSize: totalSize)
                            }
                        }
                    } else if item.sourceService is LocalFileService && destService is LocalFileService {
                        // Mac -> Mac (Local Copy)
                        let destURL = URL(fileURLWithPath: destPath).appendingPathComponent(fileItem.name)
                        try await (item.sourceService as! LocalFileService).downloadFile(at: fileItem.path, to: destURL, size: fileItem.size) { [weak self] fileProgress, status in
                            Task { @MainActor in
                                let currentFileBytes = Int64(Double(fileItem.size) * fileProgress)
                                let totalProgress = Double(totalBytesProcessed + currentFileBytes) / Double(totalSize > 0 ? totalSize : 1)
                                self?.updateProgress(progress: totalProgress, status: "Copying \(fileItem.name)...", totalSize: totalSize)
                            }
                        }
                    } else if item.sourceService is LocalFileService && destService is iOSDeviceService {
                        // Mac -> iOS (Upload)
                        let sourceURL = URL(fileURLWithPath: fileItem.path)
                        try await destService.uploadFile(from: sourceURL, to: destPath) { [weak self] fileProgress, status in
                            Task { @MainActor in
                                let currentFileBytes = Int64(Double(fileItem.size) * fileProgress)
                                let totalProgress = Double(totalBytesProcessed + currentFileBytes) / Double(totalSize > 0 ? totalSize : 1)
                                self?.updateProgress(progress: totalProgress, status: "Uploading \(fileItem.name)...", totalSize: totalSize)
                            }
                        }
                    } else if item.sourceService is iOSDeviceService && destService is LocalFileService {
                        // iOS -> Mac (Download)
                        let destURL = URL(fileURLWithPath: destPath).appendingPathComponent(fileItem.name)
                        try await item.sourceService.downloadFile(at: fileItem.path, to: destURL, size: fileItem.size) { [weak self] fileProgress, status in
                            Task { @MainActor in
                                let currentFileBytes = Int64(Double(fileItem.size) * fileProgress)
                                let totalProgress = Double(totalBytesProcessed + currentFileBytes) / Double(totalSize > 0 ? totalSize : 1)
                                self?.updateProgress(progress: totalProgress, status: "Downloading \(fileItem.name)...", totalSize: totalSize)
                            }
                        }
                    } else {
                        // Unsupported combinations
                        self.status = "Unsupported transfer type"
                        try await Task.sleep(nanoseconds: 1_000_000_000)
                    }
                    
                    totalBytesProcessed += fileItem.size
                }
                
                self.status = "Done"
                self.progress = 1.0
                self.transferSpeed = ""
                self.timeRemaining = ""
                
                // Keep "Done" message visible for a moment
                try await Task.sleep(nanoseconds: 1_500_000_000) // 1.5s
                self.isTransferring = false
                
            } catch {
                self.status = "Error: \(error.localizedDescription)"
                self.transferSpeed = ""
                self.timeRemaining = ""
                print("Transfer error: \(error)")
                
                // Show a more user-friendly error message
                let userMessage = self.getUserFriendlyErrorMessage(error)
                self.status = "Error: \(userMessage)"
                
                // Keep error visible
                try await Task.sleep(nanoseconds: 3_000_000_000) // 3s
                self.isTransferring = false
            }
        }
    }
    
    func updateProgress(progress: Double, status: String, totalSize: Int64) {
        self.progress = progress
        self.status = status
        self.totalSize = totalSize
        self.bytesTransferred = Int64(Double(totalSize) * progress)
        
        // Calculate speed and time remaining
        let now = Date()
        let currentBytes = Int64(Double(totalSize) * progress)
        
        if let lastUpdate = lastUpdateTime {
            let timeDelta = now.timeIntervalSince(lastUpdate)
            
            // Update speed more frequently (every 50ms)
            if timeDelta > 0.05 {
                let bytesDelta = currentBytes - lastBytesTransferred
                
                // Only update if we have moved forward
                if bytesDelta > 0 {
                    let instantSpeed = Double(bytesDelta) / timeDelta // bytes per second
                    
                    // Add to rolling average
                    speedSamples.append(instantSpeed)
                    if speedSamples.count > maxSpeedSamples {
                        speedSamples.removeFirst()
                    }
                    
                    // Calculate average speed from samples
                    let avgSpeed = speedSamples.reduce(0, +) / Double(speedSamples.count)
                    
                    // Format speed
                    self.transferSpeed = formatSpeed(bytesPerSecond: avgSpeed)
                    
                    // Calculate time remaining
                    let remainingBytes = totalSize - currentBytes
                    if avgSpeed > 0 {
                        let secondsRemaining = Double(remainingBytes) / avgSpeed
                        self.timeRemaining = formatTimeRemaining(seconds: secondsRemaining)
                    }
                    
                    lastUpdateTime = now
                    lastBytesTransferred = currentBytes
                }
            }
        }
    }
    
    private func formatSpeed(bytesPerSecond: Double) -> String {
        let mbps = bytesPerSecond / (1024 * 1024)
        let kbps = bytesPerSecond / 1024
        
        if mbps >= 0.1 {
            return String(format: "%.1f MB/s", mbps)
        } else {
            return String(format: "%.0f KB/s", kbps)
        }
    }
    
    private func formatTimeRemaining(seconds: Double) -> String {
        if seconds < 1 {
            return "Done"
        } else if seconds < 60 {
            return String(format: "%.0fs remaining", seconds)
        } else if seconds < 3600 {
            let minutes = Int(seconds / 60)
            let secs = Int(seconds.truncatingRemainder(dividingBy: 60))
            return "\(minutes)m \(secs)s remaining"
        } else {
            let hours = Int(seconds / 3600)
            let minutes = Int((seconds.truncatingRemainder(dividingBy: 3600)) / 60)
            return "\(hours)h \(minutes)m remaining"
        }
    }
    
    func cancel() {
        currentTask?.cancel()
        isTransferring = false
        status = "Cancelled"
        transferSpeed = ""
        timeRemaining = ""
    }
    
    private func getUserFriendlyErrorMessage(_ error: Error) -> String {
        // Provide user-friendly error messages based on error type
        if let nsError = error as NSError? {
            switch nsError.domain {
            case "ADBService": // ADB errors
                switch nsError.code {
                case 1:
                    return "Device not connected. Please connect your device and try again."
                case 2:
                    return "Device unauthorized. Please allow USB debugging on your device."
                case 3:
                    return "File not found on device."
                case 4:
                    return "Permission denied. Check file permissions on your device."
                default:
                    return nsError.localizedDescription
                }
            case "MTPService": // MTP errors
                switch nsError.code {
                case 1:
                    return "Device not connected. Please connect your device and try again."
                case 2:
                    return "Device storage not accessible. Unlock your device and try again."
                case 3:
                    return "File not found on device."
                case 4:
                    return "Permission denied. Check file permissions on your device."
                default:
                    return nsError.localizedDescription
                }
            case "iOSDeviceService": // iOS errors
                switch nsError.code {
                case 1:
                    return "Device not connected. Please connect your iOS device and try again."
                case 2:
                    return "Trust this computer dialog appeared on your iOS device. Please tap Trust."
                case 3:
                    return "File not found on device."
                case 4:
                    return "Permission denied. Check file permissions on your device."
                default:
                    return nsError.localizedDescription
                }
            default:
                // For other errors, try to provide meaningful messages
                if nsError.localizedDescription.contains("not connected") || nsError.localizedDescription.contains("device") {
                    return "Device not connected. Please connect your device and try again."
                } else if nsError.localizedDescription.contains("permission") || nsError.localizedDescription.contains("denied") {
                    return "Permission denied. Check file permissions on your device."
                } else if nsError.localizedDescription.contains("not found") || nsError.localizedDescription.contains("No such file") {
                    return "File not found. Please check the file path and try again."
                } else {
                    return nsError.localizedDescription
                }
            }
        }
        
        // Fallback to default error description
        return error.localizedDescription
    }
    
    // Handle transfers from Finder drops (direct file URLs)
    func startTransferFromURL(_ fileURL: URL, to destService: FileService, at destPath: String) {
        guard !isTransferring else { return }
        
        isTransferring = true
        filename = fileURL.lastPathComponent
        progress = 0.01 // Show at least a little bit
        status = "Preparing..."
        transferSpeed = ""
        timeRemaining = "Calculating..."
        transferStartTime = Date()
        lastUpdateTime = Date()
        lastBytesTransferred = 0
        speedSamples = []
        
        currentTask = Task {
            do {
                // Small delay to ensure UI shows "Preparing..."
                try await Task.sleep(nanoseconds: 100_000_000) // 0.1s
                
                // Get file size
                let fileSize = (try? FileManager.default.attributesOfItem(atPath: fileURL.path)[.size] as? Int64) ?? 0
                
                if destService is MTPService {
                    // Upload to Android
                    try await destService.uploadFile(from: fileURL, to: destPath) { [weak self] progress, status in
                        Task { @MainActor in
                            self?.updateProgress(progress: progress, status: status, totalSize: fileSize)
                        }
                    }
                } else if destService is iOSDeviceService {
                    // Upload to iOS
                    try await destService.uploadFile(from: fileURL, to: destPath) { [weak self] progress, status in
                        Task { @MainActor in
                            self?.updateProgress(progress: progress, status: status, totalSize: fileSize)
                        }
                    }
                } else if destService is LocalFileService {
                    // Copy to Mac
                    try await destService.uploadFile(from: fileURL, to: destPath) { [weak self] progress, status in
                        Task { @MainActor in
                            self?.updateProgress(progress: progress, status: status, totalSize: fileSize)
                        }
                    }
                }
                
                self.status = "Done"
                self.progress = 1.0
                self.transferSpeed = ""
                self.timeRemaining = ""
                
                // Keep "Done" message visible for a moment
                try await Task.sleep(nanoseconds: 1_500_000_000) // 1.5s
                self.isTransferring = false
                
            } catch {
                self.status = "Error: \(error.localizedDescription)"
                self.transferSpeed = ""
                self.timeRemaining = ""
                print("Transfer error: \(error)")
                
                // Show a more user-friendly error message
                let userMessage = self.getUserFriendlyErrorMessage(error)
                self.status = "Error: \(userMessage)"
                
                // Keep error visible
                try await Task.sleep(nanoseconds: 3_000_000_000) // 3s
                self.isTransferring = false
            }
        }
    }
    
    // Handle multiple file transfers from Finder
    func startMultipleTransfers(_ fileURLs: [URL], to destService: FileService, at destPath: String) {
        guard !isTransferring else { return }
        guard !fileURLs.isEmpty else { return }
        
        isTransferring = true
        filename = "\(fileURLs.count) files"
        progress = 0.01
        status = "Preparing..."
        transferSpeed = ""
        timeRemaining = "Calculating..."
        transferStartTime = Date()
        lastUpdateTime = Date()
        lastBytesTransferred = 0
        speedSamples = []
        
        currentTask = Task {
            do {
                // Small delay to ensure UI shows "Preparing..."
                try await Task.sleep(nanoseconds: 100_000_000) // 0.1s
                
                // Calculate total size
                var totalSize: Int64 = 0
                for url in fileURLs {
                    totalSize += (try? FileManager.default.attributesOfItem(atPath: url.path)[.size] as? Int64) ?? 0
                }
                
                var totalBytesProcessed: Int64 = 0
                
                for fileURL in fileURLs {
                    let fileSize = (try? FileManager.default.attributesOfItem(atPath: fileURL.path)[.size] as? Int64) ?? 0
                    
                    if destService is MTPService {
                        try await destService.uploadFile(from: fileURL, to: destPath) { [weak self] fileProgress, status in
                            Task { @MainActor in
                                let currentFileBytes = Int64(Double(fileSize) * fileProgress)
                                let totalProgress = Double(totalBytesProcessed + currentFileBytes) / Double(totalSize > 0 ? totalSize : 1)
                                
                                self?.updateProgress(progress: totalProgress, status: "Uploading \(fileURL.lastPathComponent)...", totalSize: totalSize)
                            }
                        }
                    } else if destService is iOSDeviceService {
                        try await destService.uploadFile(from: fileURL, to: destPath) { [weak self] fileProgress, status in
                            Task { @MainActor in
                                let currentFileBytes = Int64(Double(fileSize) * fileProgress)
                                let totalProgress = Double(totalBytesProcessed + currentFileBytes) / Double(totalSize > 0 ? totalSize : 1)
                                
                                self?.updateProgress(progress: totalProgress, status: "Uploading \(fileURL.lastPathComponent)...", totalSize: totalSize)
                            }
                        }
                    } else if destService is LocalFileService {
                        try await destService.uploadFile(from: fileURL, to: destPath) { [weak self] fileProgress, status in
                            Task { @MainActor in
                                let currentFileBytes = Int64(Double(fileSize) * fileProgress)
                                let totalProgress = Double(totalBytesProcessed + currentFileBytes) / Double(totalSize > 0 ? totalSize : 1)
                                
                                self?.updateProgress(progress: totalProgress, status: "Copying \(fileURL.lastPathComponent)...", totalSize: totalSize)
                            }
                        }
                    }
                    
                    totalBytesProcessed += fileSize
                }
                
                self.status = "Done"
                self.progress = 1.0
                self.transferSpeed = ""
                self.timeRemaining = ""
                
                // Keep "Done" message visible for a moment
                try await Task.sleep(nanoseconds: 1_500_000_000) // 1.5s
                self.isTransferring = false
                
            } catch {
                self.status = "Error: \(error.localizedDescription)"
                self.transferSpeed = ""
                self.timeRemaining = ""
                print("Transfer error: \(error)")
                
                // Show a more user-friendly error message
                let userMessage = self.getUserFriendlyErrorMessage(error)
                self.status = "Error: \(userMessage)"
                
                // Keep error visible
                try await Task.sleep(nanoseconds: 3_000_000_000) // 3s
                self.isTransferring = false
            }
        }
    }
    
    // MARK: - External Transfer Control (for NSItemProvider)
    
    func startExternalTransfer(filename: String, totalSize: Int64) {
        self.isTransferring = true
        self.filename = filename
        self.progress = 0.01 // Start with small progress to show bar
        self.status = "Preparing..."
        self.transferSpeed = ""
        self.timeRemaining = "Calculating..."
        self.transferStartTime = Date()
        self.lastUpdateTime = Date()
        self.lastBytesTransferred = 0
        self.speedSamples = []
    }
    
    func finishExternalTransfer() async {
        self.status = "Done"
        self.progress = 1.0
        self.transferSpeed = ""
        self.timeRemaining = ""
        try? await Task.sleep(nanoseconds: 1_500_000_000) // 1.5s
        self.isTransferring = false
    }
    
    func failExternalTransfer(error: Error) async {
        self.status = "Error: \(error.localizedDescription)"
        self.transferSpeed = ""
        self.timeRemaining = ""
        print("External transfer error: \(error)")
        
        // Show a more user-friendly error message
        let userMessage = self.getUserFriendlyErrorMessage(error)
        self.status = "Error: \(userMessage)"
        
        try? await Task.sleep(nanoseconds: 3_000_000_000) // 3s
        self.isTransferring = false
    }
}

