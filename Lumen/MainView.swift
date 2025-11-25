//
//  MainView.swift
//  Lumen
//
//  Created by Zaki Sheriff on 2025-11-25.
//

import SwiftUI
import AppKit

struct MainView: View {
    @State private var selectedCategory: String? = "split"
    @State private var clipboard: ClipboardItem?
    @StateObject private var transferManager = TransferManager()
    
    // Services
    let localService = LocalFileService()
    let remoteService = MTPService() // Switched to MTP
    
    var body: some View {
        NavigationSplitView {
            SidebarView(selectedCategory: $selectedCategory)
        } detail: {
            ZStack {
                Group {
                    if selectedCategory == "mac" {
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
                    } else if selectedCategory == "android" {
                        FileBrowserView(
                            title: "Android",
                            fileService: remoteService,
                            currentPath: "mtp://",
                            clipboard: $clipboard,
                            onPaste: { destPath in
                                transferManager.startTransfer(item: clipboard!, to: remoteService, at: destPath)
                            }
                        )
                        .frame(minWidth: 300, maxWidth: .infinity, maxHeight: .infinity)
                    } else {
                        // Split View
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
                                currentPath: "mtp://",
                                clipboard: $clipboard,
                                onPaste: { destPath in
                                    transferManager.startTransfer(item: clipboard!, to: remoteService, at: destPath)
                                }
                            )
                            .frame(minWidth: 300, maxWidth: .infinity, maxHeight: .infinity)
                        }
                    }
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
            // .background(.regularMaterial) // Removed to allow unified window background to show through
        }
        .frame(minWidth: 800, minHeight: 500)
        .toolbar {
            ToolbarItemGroup(placement: .automatic) {
                // Buy Me a Coffee button in toolbar
                BuyMeACoffeeButton {
                    openCoffeePurchaseURL()
                }
            }
        }
    }
    
    private func openCoffeePurchaseURL() {
        #if DEBUG
        print("Opening Buy Me a Coffee URL...")
        #endif
        if let url = URL(string: "https://buymeacoffee.com/zakisherifw") {
            NSWorkspace.shared.open(url)
        }
    }
}

#Preview {
    MainView()
}