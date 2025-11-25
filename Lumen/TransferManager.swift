//
//  TransferManager.swift
//  Lumen
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
    
    private var currentTask: Task<Void, Never>?
    private var transferStartTime: Date?
    private var lastUpdateTime: Date?
    private var lastBytesTransferred: Int64 = 0
    private var speedSamples: [Double] = [] // Rolling window for smooth speed calculation
    private let maxSpeedSamples = 10 // Keep last 10 samples
    
    func startTransfer(item: ClipboardItem, to destService: FileService, at destPath: String) {
        guard !isTransferring else { return }
        
        isTransferring = true
        filename = item.item.name
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
                // Determine transfer type
                if item.sourceService is LocalFileService && destService is MTPService {
                    // Mac -> Android (Upload)
                    let sourceURL = URL(fileURLWithPath: item.item.path)
                    try await destService.uploadFile(from: sourceURL, to: destPath) { [weak self] progress, status in
                        Task { @MainActor in
                            self?.updateProgress(progress: progress, status: status, totalSize: item.item.size)
                        }
                    }
                } else if item.sourceService is MTPService && destService is LocalFileService {
                    // Android -> Mac (Download)
                    let destURL = URL(fileURLWithPath: destPath).appendingPathComponent(item.item.name)
                    try await item.sourceService.downloadFile(at: item.item.path, to: destURL, size: item.item.size) { [weak self] progress, status in
                        Task { @MainActor in
                            self?.updateProgress(progress: progress, status: status, totalSize: item.item.size)
                        }
                    }
                } else if item.sourceService is LocalFileService && destService is LocalFileService {
                     // Mac -> Mac (Local Copy)
                    let destURL = URL(fileURLWithPath: destPath).appendingPathComponent(item.item.name)
                    try await (item.sourceService as! LocalFileService).downloadFile(at: item.item.path, to: destURL, size: item.item.size) { [weak self] progress, status in
                         Task { @MainActor in
                            self?.updateProgress(progress: progress, status: status, totalSize: item.item.size)
                        }
                    }
                } else {
                    // Android -> Android (Not supported yet)
                    self.status = "Direct Android-to-Android transfer not supported"
                    try await Task.sleep(nanoseconds: 2_000_000_000)
                }
                
                self.isTransferring = false
                self.status = "Done"
                self.transferSpeed = ""
                self.timeRemaining = ""
                
            } catch {
                self.isTransferring = false
                self.status = "Error: \(error.localizedDescription)"
                self.transferSpeed = ""
                self.timeRemaining = ""
                print("Transfer error: \(error)")
            }
        }
    }
    
    private func updateProgress(progress: Double, status: String, totalSize: Int64) {
        self.progress = progress
        self.status = status
        
        // Calculate speed and time remaining
        let now = Date()
        let currentBytes = Int64(Double(totalSize) * progress)
        
        if let lastUpdate = lastUpdateTime {
            let timeDelta = now.timeIntervalSince(lastUpdate)
            
            // Only update speed if enough time has passed (avoid division by very small numbers)
            if timeDelta > 0.1 {
                let bytesDelta = currentBytes - lastBytesTransferred
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
    
    private func formatSpeed(bytesPerSecond: Double) -> String {
        let mbps = bytesPerSecond / (1024 * 1024)
        let kbps = bytesPerSecond / 1024
        
        if mbps >= 1 {
            return String(format: "%.1f MB/s", mbps)
        } else {
            return String(format: "%.0f KB/s", kbps)
        }
    }
    
    private func formatTimeRemaining(seconds: Double) -> String {
        if seconds < 60 {
            return String(format: "%.0f seconds", seconds)
        } else if seconds < 3600 {
            let minutes = Int(seconds / 60)
            let secs = Int(seconds.truncatingRemainder(dividingBy: 60))
            return "\(minutes)m \(secs)s"
        } else {
            let hours = Int(seconds / 3600)
            let minutes = Int((seconds.truncatingRemainder(dividingBy: 3600)) / 60)
            return "\(hours)h \(minutes)m"
        }
    }
    
    func cancel() {
        currentTask?.cancel()
        isTransferring = false
        status = "Cancelled"
        transferSpeed = ""
        timeRemaining = ""
    }
}

