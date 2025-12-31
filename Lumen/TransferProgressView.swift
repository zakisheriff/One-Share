//
//  TransferProgressView.swift
//  One Share
//
//  Created by Zaki Sheriff on 2025-11-25.
//

import SwiftUI

struct TransferProgressView: View {
    let filename: String
    let progress: Double // 0.0 to 1.0
    let status: String
    let transferSpeed: String
    let timeRemaining: String
    let totalSize: Int64
    let bytesTransferred: Int64
    let onCancel: () -> Void
    
    // Format bytes to human readable string
    private func formatBytes(_ bytes: Int64) -> String {
        let kb = Double(bytes) / 1024
        let mb = kb / 1024
        let gb = mb / 1024
        
        if gb >= 1.0 {
            return String(format: "%.2f GB", gb)
        } else if mb >= 1.0 {
            return String(format: "%.1f MB", mb)
        } else if kb >= 1.0 {
            return String(format: "%.0f KB", kb)
        } else {
            return "\(bytes) B"
        }
    }
    
    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack(alignment: .top, spacing: 16) {
                Image(systemName: "doc.fill")
                    .font(.system(size: 32))
                    .foregroundStyle(
                        LinearGradient(colors: [.blue, .cyan], startPoint: .topLeading, endPoint: .bottomTrailing)
                    )
                    .frame(width: 48, height: 48)
                    .background(.blue.opacity(0.1))
                    .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
                    .shadow(color: .blue.opacity(0.2), radius: 5, x: 0, y: 2)
                
                VStack(alignment: .leading, spacing: 4) {
                    Text("Copying \"\(filename)\"")
                        .font(.system(.headline, design: .rounded))
                        .lineLimit(1)
                    
                    Text(status)
                        .font(.system(.caption, design: .rounded))
                        .foregroundStyle(.secondary)
                    
                    // Percentage
                    Text("\(Int(progress * 100))%")
                        .font(.system(.title3, design: .rounded))
                        .fontWeight(.semibold)
                        .foregroundStyle(.primary)
                    
                    // Size transferred (e.g. "245.3 MB of 3.2 GB")
                    if totalSize > 0 {
                        Text("\(formatBytes(bytesTransferred)) of \(formatBytes(totalSize))")
                            .font(.system(.caption, design: .rounded))
                            .foregroundStyle(.secondary)
                    }
                    
                    // Speed and time remaining
                    HStack(spacing: 12) {
                        if !transferSpeed.isEmpty {
                            HStack(spacing: 4) {
                                Image(systemName: "speedometer")
                                    .font(.caption2)
                                Text(transferSpeed)
                                    .font(.system(.caption, design: .rounded))
                            }
                            .foregroundStyle(.secondary)
                        }
                        
                        if !timeRemaining.isEmpty {
                            HStack(spacing: 4) {
                                Image(systemName: "clock")
                                    .font(.caption2)
                                Text(timeRemaining)
                                    .font(.system(.caption, design: .rounded))
                            }
                            .foregroundStyle(.secondary)
                        }
                    }
                }
                
                Spacer()
                
                Button(action: onCancel) {
                    Image(systemName: "xmark.circle.fill")
                        .font(.system(size: 20))
                        .foregroundStyle(.secondary.opacity(0.5))
                }
                .buttonStyle(.plain)

            }
            
            // Liquid Progress Bar
            GeometryReader { geometry in
                ZStack(alignment: .leading) {
                    Capsule()
                        .fill(.secondary.opacity(0.1))
                        .frame(height: 6)
                    
                    Capsule()
                        .fill(
                            LinearGradient(colors: [.blue, .cyan], startPoint: .leading, endPoint: .trailing)
                        )
                        .frame(width: max(0, geometry.size.width * progress), height: 6)
                        .shadow(color: .blue.opacity(0.5), radius: 4, x: 0, y: 0)
                }
            }
            .frame(height: 6)
        }
        .padding(20)
        .frame(width: 400)
        .background(VisualEffectView(material: .hudWindow, blendingMode: .withinWindow))
        .clipShape(RoundedRectangle(cornerRadius: 20, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 20, style: .continuous)
                .stroke(.white.opacity(0.1), lineWidth: 1)
        )
        .shadow(color: .black.opacity(0.2), radius: 20, x: 0, y: 10)
    }
}

