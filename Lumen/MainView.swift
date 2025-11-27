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
    @EnvironmentObject var transferManager: TransferManager
    @EnvironmentObject var deviceManager: DeviceManager
    
    // AI Search
    @StateObject private var geminiService = GeminiService()
    @EnvironmentObject var fileScanner: FileScanner
    @State private var showAISearch = false
    
    // Services - use shared instances from DeviceManager
    let localService = LocalFileService()
    
    // Computed properties to get services from DeviceManager
    private var remoteService: MTPService {
        return deviceManager.getDeviceService(for: .android) as? MTPService ?? MTPService()
    }
    
    private var iOSRemoteService: iOSDeviceService {
        return deviceManager.getDeviceService(for: .ios) as? iOSDeviceService ?? iOSDeviceService()
    }
    
    var body: some View {
        NavigationSplitView {
            SidebarView(selectedCategory: $selectedCategory, deviceManager: deviceManager)
                .background(VisualEffectView(material: .sidebar, blendingMode: .behindWindow))
        } detail: {
            ZStack {
                // Liquid Glass Background
                VisualEffectView(material: .contentBackground, blendingMode: .behindWindow)
                    .ignoresSafeArea()
                
                Group {
                    if selectedCategory == "mac" {
                        FileBrowserView(
                            title: "Mac",
                            fileService: localService,
                            currentPath: FileManager.default.homeDirectoryForCurrentUser.path,
                            transferManager: transferManager,
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
                            transferManager: transferManager,
                            clipboard: $clipboard,
                            onPaste: { destPath in
                                transferManager.startTransfer(item: clipboard!, to: remoteService, at: destPath)
                            }
                        )
                        .frame(minWidth: 300, maxWidth: .infinity, maxHeight: .infinity)
                    } else if selectedCategory == "ios" {
                        FileBrowserView(
                            title: "iOS",
                            fileService: iOSRemoteService,
                            currentPath: "/",
                            transferManager: transferManager,
                            clipboard: $clipboard,
                            onPaste: { destPath in
                                transferManager.startTransfer(item: clipboard!, to: iOSRemoteService, at: destPath)
                            }
                        )
                        .frame(minWidth: 300, maxWidth: .infinity, maxHeight: .infinity)
                    } else {
                        // Split View
                        GeometryReader { geometry in
                            HStack(spacing: 0) {
                                // Mac Pane
                                FileBrowserView(
                                    title: "Mac",
                                    fileService: localService,
                                    currentPath: FileManager.default.homeDirectoryForCurrentUser.path,
                                    transferManager: transferManager,
                                    clipboard: $clipboard,
                                    onPaste: { destPath in
                                        transferManager.startTransfer(item: clipboard!, to: localService, at: destPath)
                                    }
                                )
                                .frame(width: max(0, geometry.size.width * splitRatio))
                                .clipped() // Prevent overflow covering the handle
                                
                                // Glass Divider
                                ZStack {
                                    Rectangle()
                                        .fill(.white.opacity(0.1))
                                        .frame(width: 1)
                                    
                                    // Handle
                                    Capsule()
                                        .fill(.secondary.opacity(0.3))
                                        .frame(width: 4, height: 40)
                                }
                                .frame(width: 9)
                                .contentShape(Rectangle())
                                .gesture(
                                    DragGesture(coordinateSpace: .named("splitView"))
                                        .onChanged { value in
                                            let newRatio = value.location.x / geometry.size.width
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
                                .zIndex(10) // Ensure handle is always on top
                                
                                // Android Pane
                                FileBrowserView(
                                    title: "Android",
                                    fileService: remoteService,
                                    currentPath: "mtp://",
                                    transferManager: transferManager,
                                    clipboard: $clipboard,
                                    onPaste: { destPath in
                                        transferManager.startTransfer(item: clipboard!, to: remoteService, at: destPath)
                                    }
                                )
                                .frame(width: max(0, geometry.size.width * (1 - splitRatio) - 9))
                                .clipped() // Prevent overflow covering the handle
                            }
                        }
                        .coordinateSpace(name: "splitView")
                    }
                }
                .padding(10) // Add some breathing room for the floating effect
            }
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
                        .font(.system(size: 14, weight: .medium))
                }
                
                // Center Split Button
                if selectedCategory == "split" {
                    Button(action: {
                        withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) {
                            splitRatio = 0.5
                        }
                    }) {
                        Image(systemName: "rectangle.split.2x1")
                        .font(.system(size: 14, weight: .medium))
                    }
                }
                
                // AI Search Button
                Button(action: { showAISearch.toggle() }) {
                    Image(systemName: "sparkles")
                        .symbolEffect(.pulse.byLayer, isActive: showAISearch)
                        .foregroundStyle(.linearGradient(colors: [.purple, .blue], startPoint: .topLeading, endPoint: .bottomTrailing))
                }
                
                // Buy Me a Coffee button
                BuyMeACoffeeButton {
                    openCoffeePurchaseURL()
                }
            }
        }
        .overlay(
            Group {
                if showAISearch {
                    ZStack {
                        Color.black.opacity(0.2)
                            .edgesIgnoringSafeArea(.all)
                            .onTapGesture {
                                showAISearch = false
                            }
                        
                        AISearchView(
                            scanner: fileScanner,
                            geminiService: geminiService,
                            clipboard: $clipboard,
                            onOpen: { file in
                                if file.isRemote {
                                    print("Opening remote file: \(file.path)")
                                } else {
                                    NSWorkspace.shared.open(URL(fileURLWithPath: file.path))
                                }
                            },
                            onClose: {
                                showAISearch = false
                            }
                        )
                        .frame(width: 600, height: 400)
                        .background(VisualEffectView(material: .popover, blendingMode: .withinWindow))
                        .clipShape(RoundedRectangle(cornerRadius: 20))
                        .shadow(color: .black.opacity(0.2), radius: 20, x: 0, y: 10)
                        .overlay(
                            RoundedRectangle(cornerRadius: 20)
                                .stroke(.white.opacity(0.2), lineWidth: 1)
                        )
                    }
                    .transition(.opacity.combined(with: .scale(scale: 0.95)))
                    .zIndex(200)
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
        .environmentObject(DeviceManager(mtpService: nil, iosService: nil))
        .environmentObject(TransferManager())
        .environmentObject(FileScanner(mtpService: MTPService()))
}