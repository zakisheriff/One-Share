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
    @State private var splitRatio: CGFloat = 0.5
    @StateObject private var transferManager = TransferManager()
    
    // AI Search
    @StateObject private var geminiService = GeminiService()
    @StateObject private var fileScanner: FileScanner
    @State private var showAISearch = false
    
    init() {
        let mtp = MTPService()
        _remoteService = State(initialValue: mtp)
        _fileScanner = StateObject(wrappedValue: FileScanner(mtpService: mtp))
    }
    
    // Services
    let localService = LocalFileService()
    @State private var remoteService: MTPService // Changed to State to share with scanner
    
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
                        // Custom Split View
                        // Custom Split View
                        GeometryReader { geometry in
                            HStack(spacing: 0) {
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
                                .frame(width: max(0, geometry.size.width * splitRatio))
                                
                                // Draggable Divider
                                ZStack {
                                    Rectangle()
                                        .fill(Color.secondary.opacity(0.2))
                                        .frame(width: 1)
                                    
                                    // Invisible handle for easier grabbing
                                    Rectangle()
                                        .fill(Color.clear)
                                        .frame(width: 9)
                                }
                                .contentShape(Rectangle())
                                .gesture(
                                    DragGesture(coordinateSpace: .named("splitView"))
                                        .onChanged { value in
                                            let newRatio = value.location.x / geometry.size.width
                                            // Clamp between 20% and 80%
                                            splitRatio = min(max(newRatio, 0.2), 0.8)
                                        }
                                )
                                .onHover { inside in
                                    if inside {
                                        NSCursor.resizeLeftRight.push()
                                    } else {
                                        NSCursor.pop()
                                    }
                                }
                                
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
                                .frame(width: max(0, geometry.size.width * (1 - splitRatio) - 1))
                            }
                        }
                        .coordinateSpace(name: "splitView")
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
                // Window Size Menu
                Menu {
                    Button("Maximize") {
                        resizeWindow(to: 1.0)
                    }
                    Button("75% Size") {
                        resizeWindow(to: 0.75)
                    }
                    Button("50% Size") {
                        resizeWindow(to: 0.5)
                    }
                } label: {
                    Image(systemName: "arrow.up.left.and.arrow.down.right")
                        .help("Window Size")
                }
                
                // Center Split Button
                if selectedCategory == "split" {
                    Button(action: {
                        withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) {
                            splitRatio = 0.5
                        }
                    }) {
                        Image(systemName: "rectangle.split.2x1")
                            .help("Center Split")
                    }
                }
                
                // AI Search Button
                Button(action: { showAISearch.toggle() }) {
                    Image(systemName: "sparkles")
                        .foregroundStyle(.purple)
                }
                
                // Buy Me a Coffee button in toolbar
                BuyMeACoffeeButton {
                    openCoffeePurchaseURL()
                }
            }
        }
        .overlay(
            Group {
                if showAISearch {
                    ZStack {
                        Color.black.opacity(0.4)
                            .edgesIgnoringSafeArea(.all)
                            .onTapGesture {
                                // Optional: Uncomment to allow closing by clicking background
                                // showAISearch = false
                            }
                        
                        AISearchView(
                            scanner: fileScanner,
                            geminiService: geminiService,
                            clipboard: $clipboard,
                            onOpen: { file in
                                // Handle opening/transferring file
                                if file.isRemote {
                                    print("Opening remote file: \(file.path)")
                                } else {
                                    NSWorkspace.shared.open(URL(fileURLWithPath: file.path))
                                }
                                // showAISearch = false // Keep open as requested
                            },
                            onClose: {
                                showAISearch = false
                            }
                        )
                        .shadow(radius: 20)
                    }
                    .transition(.opacity)
                }
            }
        )
    }
    
    private func openCoffeePurchaseURL() {
        #if DEBUG
        print("Opening Buy Me a Coffee URL...")
        #endif
        if let url = URL(string: "https://buymeacoffee.com/zakisherifw") {
            NSWorkspace.shared.open(url)
        }
    }
    
    private func resizeWindow(to scale: CGFloat) {
        guard let screen = NSScreen.main else { return }
        let visibleFrame = screen.visibleFrame
        
        let newWidth: CGFloat
        let newHeight: CGFloat
        
        if scale >= 0.99 {
            // Maximize case: Full width and height
            newWidth = visibleFrame.width
            newHeight = visibleFrame.height
        } else {
            // Partial size case: 90% width, scaled height
            newWidth = visibleFrame.width * 0.9
            newHeight = visibleFrame.height * scale
        }
        
        // Center the window
        let newX = visibleFrame.minX + (visibleFrame.width - newWidth) / 2
        let newY = visibleFrame.minY + (visibleFrame.height - newHeight) / 2
        
        let newFrame = NSRect(x: newX, y: newY, width: newWidth, height: newHeight)
        
        // Use mainWindow if available, otherwise fall back to windows.first
        if let window = NSApplication.shared.mainWindow ?? NSApplication.shared.windows.first {
            window.setFrame(newFrame, display: true, animate: true)
            window.makeKeyAndOrderFront(nil)
        }
    }
}

#Preview {
    MainView()
}