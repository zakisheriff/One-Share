//
//  TransferProgressView.swift
//  Lumen
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
    let onCancel: () -> Void
    
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(alignment: .top, spacing: 12) {
                Image(systemName: "doc.fill") // Generic file icon
                    .resizable()
                    .aspectRatio(contentMode: .fit)
                    .frame(width: 48, height: 48)
                    .foregroundStyle(.blue)
                
                VStack(alignment: .leading, spacing: 4) {
                    Text("Copying \"\(filename)\"")
                        .font(.headline)
                    
                    Text(status)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                    
                    // Speed and time remaining
                    HStack(spacing: 8) {
                        if !transferSpeed.isEmpty {
                            HStack(spacing: 4) {
                                Image(systemName: "speedometer")
                                    .font(.caption2)
                                Text(transferSpeed)
                                    .font(.caption)
                            }
                            .foregroundStyle(.secondary)
                        }
                        
                        if !timeRemaining.isEmpty {
                            HStack(spacing: 4) {
                                Image(systemName: "clock")
                                    .font(.caption2)
                                Text(timeRemaining)
                                    .font(.caption)
                            }
                            .foregroundStyle(.secondary)
                        }
                    }
                }
                
                Spacer()
                
                Button(action: onCancel) {
                    Image(systemName: "xmark.circle.fill")
                        .foregroundStyle(.secondary)
                }
                .buttonStyle(.plain)
            }
            
            ProgressView(value: progress)
                .progressViewStyle(.linear)
        }
        .padding()
        .frame(width: 400)
        .background(.ultraThinMaterial) // Native material
        .cornerRadius(12)
        .shadow(radius: 10)
    }
}

