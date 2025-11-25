//
//  MainView.swift
//  Lumen
//
//  Created by Zaki Sheriff on 2025-11-25.
//

import SwiftUI

struct MainView: View {
    @State private var selectedCategory: String? = "local"
    @State private var clipboard: ClipboardItem?
    @StateObject private var transferManager = TransferManager()
    
    // Services
    let localService = LocalFileService()
    let remoteService = MTPService() // Switched to MTP
    
    var body: some View {
        NavigationSplitView {
            SidebarView(selectedCategory: $selectedCategory)
                .background(.ultraThinMaterial) // Native sidebar material
        } detail: {
            ZStack {
                HSplitView {
                    // Mac Pane - Real File System
                    FileBrowserView(
                        title: "Mac",
                        fileService: localService,
                        currentPath: FileManager.default.homeDirectoryForCurrentUser.path,
                        clipboard: $clipboard,
                        onPaste: { destPath in
                            transferManager.startTransfer(item: clipboard!, to: localService, at: destPath)
                        }
                    )
                    .frame(minWidth: 300, maxWidth: .infinity, maxHeight: .infinity)
                    
                    // Android Pane - Real MTP Connection
                    FileBrowserView(
                        title: "Android",
                        fileService: remoteService,
                        currentPath: "mtp://", // Root MTP path
                        clipboard: $clipboard,
                        onPaste: { destPath in
                            transferManager.startTransfer(item: clipboard!, to: remoteService, at: destPath)
                        }
                    )
                    .frame(minWidth: 300, maxWidth: .infinity, maxHeight: .infinity)
                }
                .padding()
                
                if transferManager.isTransferring {
                    Color.black.opacity(0.3)
                        .edgesIgnoringSafeArea(.all)
                    
                    TransferProgressView(
                        filename: transferManager.filename,
                        progress: transferManager.progress,
                        status: transferManager.status,
                        transferSpeed: transferManager.transferSpeed,
                        timeRemaining: transferManager.timeRemaining,
                        onCancel: {
                            transferManager.cancel()
                        }
                    )
                }
            }
            .background(.regularMaterial) // Main content glass effect
        }
        .frame(minWidth: 800, minHeight: 500)
    }
}

#Preview {
    MainView()
}
