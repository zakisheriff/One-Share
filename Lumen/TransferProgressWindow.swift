//
//  TransferProgressWindow.swift
//  One Share
//
//  Created by Zaki Sheriff on 2025-11-25.
//

import SwiftUI

struct TransferProgressWindow: View {
    @EnvironmentObject var transferManager: TransferManager
    @Environment(\.dismiss) var dismiss
    
    var body: some View {
        TransferProgressView(
            filename: transferManager.filename,
            progress: transferManager.progress,
            status: transferManager.status,
            transferSpeed: transferManager.transferSpeed,
            timeRemaining: transferManager.timeRemaining,
            totalSize: transferManager.totalSize,
            bytesTransferred: transferManager.bytesTransferred,
            onCancel: {
                transferManager.cancel()
                dismiss()
            }
        )
        .padding(0) // Remove extra padding if TransferProgressView has it
        .edgesIgnoringSafeArea(.all)
        // We don't need the background material here if the window itself handles it
        // But TransferProgressView has it built-in.
        // Let's keep it for now.
        .onChange(of: transferManager.isTransferring) { _, isTransferring in
            if !isTransferring {
                dismiss()
            }
        }
    }
}
