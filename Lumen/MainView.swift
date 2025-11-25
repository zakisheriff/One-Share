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
    @State private var transferStatus: String?
    
    // Services
    let localService = LocalFileService()
    let remoteService = ADBService()
    
    // Paste Handler
    func handlePaste(to destService: FileService, at destPath: String) {
        guard let item = clipboard else { return }
        
        transferStatus = "Transferring \(item.item.name)..."
        
        DispatchQueue.global(qos: .userInitiated).async {
            do {
                // Determine transfer type
                if item.sourceService is LocalFileService && destService is ADBService {
                    // Mac -> Android (Upload)
                    let sourceURL = URL(fileURLWithPath: item.item.path)
                    try destService.uploadFile(from: sourceURL, to: destPath)
                } else if item.sourceService is ADBService && destService is LocalFileService {
                    // Android -> Mac (Download)
                    let destURL = URL(fileURLWithPath: destPath).appendingPathComponent(item.item.name)
                    try item.sourceService.downloadFile(at: item.item.path, to: destURL)
                } else if item.sourceService is LocalFileService && destService is LocalFileService {
                     // Mac -> Mac (Local Copy)
                    let sourceURL = URL(fileURLWithPath: item.item.path)
                    let destURL = URL(fileURLWithPath: destPath).appendingPathComponent(item.item.name)
                    try FileManager.default.copyItem(at: sourceURL, to: destURL)
                } else {
                    // Android -> Android (Not implemented efficiently yet, would need shell cp)
                    // For now, skip or implement shell cp in ADBService
                }
                
                DispatchQueue.main.async {
                    transferStatus = nil
                }
            } catch {
                DispatchQueue.main.async {
                    transferStatus = "Error: \(error.localizedDescription)"
                }
            }
        }
    }
    
    var body: some View {
        NavigationSplitView {
            SidebarView(selectedCategory: $selectedCategory)
        } detail: {
            VStack(spacing: 0) {
                if let status = transferStatus {
                    HStack {
                        ProgressView()
                            .scaleEffect(0.5)
                        Text(status)
                            .font(.caption)
                    }
                    .padding(4)
                    .background(Color.yellow.opacity(0.2))
                    .cornerRadius(4)
                }
                
                HSplitView {
                    // Mac Pane - Real File System
                    FileBrowserView(
                        title: "Mac",
                        fileService: localService,
                        currentPath: FileManager.default.homeDirectoryForCurrentUser.path,
                        clipboard: $clipboard,
                        onPaste: { destPath in
                            handlePaste(to: localService, at: destPath)
                        }
                    )
                    .frame(minWidth: 300, maxWidth: .infinity, maxHeight: .infinity)
                    
                    // Android Pane - Real ADB Connection
                    FileBrowserView(
                        title: "Android",
                        fileService: remoteService,
                        currentPath: "/sdcard",
                        clipboard: $clipboard,
                        onPaste: { destPath in
                            handlePaste(to: remoteService, at: destPath)
                        }
                    )
                    .frame(minWidth: 300, maxWidth: .infinity, maxHeight: .infinity)
                }
                .padding()
            }
        }
        .frame(minWidth: 800, minHeight: 500)
    }
}

#Preview {
    MainView()
}
