//
//  OneShareApp.swift
//  One Share
//
//  Created by Zaki Sheriff on 2025-11-25.
//

import SwiftUI

@main
struct OneShareApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) var appDelegate
    @StateObject private var transferManager = TransferManager()
    
    // Create shared service instances
    @StateObject private var mtpService = MTPService()
    @StateObject private var iosService = iOSDeviceService()
    
    // Pass shared services to DeviceManager
    @StateObject private var deviceManager: DeviceManager
    
    // FileScanner needs MTPService
    @StateObject private var fileScanner: FileScanner
    
    init() {
        let mtp = MTPService()
        let ios = iOSDeviceService()
        _mtpService = StateObject(wrappedValue: mtp)
        _iosService = StateObject(wrappedValue: ios)
        _deviceManager = StateObject(wrappedValue: DeviceManager(mtpService: mtp, iosService: ios))
        _fileScanner = StateObject(wrappedValue: FileScanner(mtpService: mtp))
    }
    
    var body: some Scene {
        WindowGroup {
            ContentView()
                .environmentObject(transferManager)
                .environmentObject(deviceManager)
                .environmentObject(fileScanner)
                .background(VisualEffectView(material: .sidebar, blendingMode: .behindWindow).ignoresSafeArea())
                .background(WindowAccessor(transferManager: transferManager))
        }
        .windowStyle(.hiddenTitleBar)
        .windowToolbarStyle(.unified)
        .commands {
            WindowSizeCommands()
        }
        
        WindowGroup(id: "transfer-progress") {
            TransferProgressWindow()
                .environmentObject(transferManager)
                .frame(width: 400, height: 160)
                .fixedSize()
        }
        .windowStyle(.hiddenTitleBar)
        .windowResizability(.contentSize)
        .defaultPosition(.center)
    }
}

// Helper to access window for opening other windows
struct WindowAccessor: View {
    @ObservedObject var transferManager: TransferManager
    @Environment(\.openWindow) var openWindow
    @Environment(\.dismissWindow) var dismissWindow
    
    var body: some View {
        EmptyView()
            .onChange(of: transferManager.isTransferring) { isTransferring in
                if isTransferring {
                    openWindow(id: "transfer-progress")
                } else {
                    // We let the window dismiss itself or use dismissWindow
                    // dismissWindow(id: "transfer-progress") // Optional, but safer to let window handle it
                }
            }
    }
}

struct VisualEffectView: NSViewRepresentable {
    let material: NSVisualEffectView.Material
    let blendingMode: NSVisualEffectView.BlendingMode
    
    func makeNSView(context: Context) -> NSVisualEffectView {
        let visualEffectView = NSVisualEffectView()
        visualEffectView.material = material
        visualEffectView.blendingMode = blendingMode
        visualEffectView.state = .active
        return visualEffectView
    }
    
    func updateNSView(_ visualEffectView: NSVisualEffectView, context: Context) {
        visualEffectView.material = material
        visualEffectView.blendingMode = blendingMode
    }
}

struct WindowSizeCommands: Commands {
    var body: some Commands {
        CommandMenu("Window Size") {
            Button("Maximize (Almost Full Screen)") {
                resizeWindow(to: 1.0)
            }
            .keyboardShortcut("1", modifiers: [.command, .option])
            
            Button("75% Size") {
                resizeWindow(to: 0.75)
            }
            .keyboardShortcut("2", modifiers: [.command, .option])
            
            Button("50% Size") {
                resizeWindow(to: 0.5)
            }
            .keyboardShortcut("3", modifiers: [.command, .option])
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

class AppDelegate: NSObject, NSApplicationDelegate {
    func applicationDidFinishLaunching(_ notification: Notification) {
        // Maximize the window on launch with a slight delay to ensure window is ready
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
            if let window = NSApplication.shared.windows.first {
                window.setFrame(NSScreen.main?.visibleFrame ?? NSRect(x: 0, y: 0, width: 1200, height: 800), display: true)
                window.makeKeyAndOrderFront(nil)
            }
        }
    }
}