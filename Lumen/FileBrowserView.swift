//
//  FileBrowserView.swift
//  One Share
//
//  Created by Zaki Sheriff on 2025-11-25.
//

import SwiftUI
import AppKit
import UniformTypeIdentifiers

// MARK: - Preference Key for Item Frames (Marquee Selection)
struct ItemFramePreferenceKey: PreferenceKey {
    static var defaultValue: [UUID: CGRect] = [:]
    
    static func reduce(value: inout [UUID: CGRect], nextValue: () -> [UUID: CGRect]) {
        value.merge(nextValue()) { _, new in new }
    }
}

struct FileBrowserView: View {
    let title: String
    let fileService: FileService
    @State var currentPath: String
    let transferManager: TransferManager
    
    @State private var items: [FileSystemItem] = []
    @State private var selection = Set<UUID>()
    @State private var lastSelectedId: UUID?
    @State private var errorMessage: String?
    
    // MARK: - Performance Optimization States
    @State private var isLoading: Bool = false
    @State private var cachedFilteredItems: [FileSystemItem] = []
    
    // Finder Features State
    @State private var searchText = ""
    @State private var sortOption: ExtendedSortOption = .name
    @State private var sortOrder: SortOrder = .ascending
    @State private var isGridView = true
    @State private var iconSize: CGFloat = 64
    
    // Navigation history
    @State private var navigationHistory: [String] = []
    @State private var currentHistoryIndex: Int = -1
    @State private var homePath: String = ""
    
    // Auto-refresh state
    @State private var isAutoRefreshing: Bool = false
    @State private var connectionState: ConnectionState = .disconnected
    
    // MARK: - Marquee Selection State
    @State private var isDraggingMarquee: Bool = false
    @State private var marqueeStart: CGPoint = .zero
    @State private var marqueeEnd: CGPoint = .zero
    @State private var itemFrames: [UUID: CGRect] = [:]
    @State private var selectionBeforeDrag: Set<UUID> = []
    
    // Computed properties for path display and navigation
    private var canNavigateUp: Bool {
        // For local files, enable up button if not at root
        if !currentPath.hasPrefix("mtp://") && !currentPath.hasPrefix("ios://") {
            return currentPath != "/"
        }
        
        // For MTP, enable up button if we're not at the storage root
        // Format: mtp://storageId/fileId or deeper
        if currentPath.hasPrefix("mtp://") {
            let cleanPath = currentPath.replacingOccurrences(of: "mtp://", with: "")
            let components = cleanPath.split(separator: "/")
            return components.count > 1
        }
        
        // For iOS, enable up button if we're not at root
        if currentPath.hasPrefix("ios://") {
            let cleanPath = currentPath.replacingOccurrences(of: "ios://", with: "")
            return cleanPath != "/" && !cleanPath.isEmpty
        }
        
        return currentPath != "/"
    }

    private var canNavigateBack: Bool {
        return currentHistoryIndex > 0
    }

    private var canNavigateForward: Bool {
        return currentHistoryIndex < navigationHistory.count - 1
    }

    private func displayPath(_ path: String) -> String {
        // For local files, return the path as is
        if !path.hasPrefix("mtp://") && !path.hasPrefix("ios://") {
            return path
        }
        
        // For MTP paths, show a more user-friendly representation
        if path.hasPrefix("mtp://") {
            if path == "mtp://" || path.isEmpty || path == "/" {
                // Try to get actual device name
                if let mtpService = fileService as? MTPService {
                    return mtpService.getDeviceName()
                }
                return "Android Device"
            }
            
            // For deeper paths, show the navigation trail
            let cleanPath = path.replacingOccurrences(of: "mtp://", with: "")
            let components = cleanPath.split(separator: "/")
            if components.count <= 1 {
                // Try to get actual device name
                if let mtpService = fileService as? MTPService {
                    return mtpService.getDeviceName()
                }
                return "Android Device"
            }
            
            // Show breadcrumbs: Android Device > Folder1 > Folder2
            // Try to get actual device name
            var breadcrumbs = ["Android Device"]
            if let mtpService = fileService as? MTPService {
                breadcrumbs[0] = mtpService.getDeviceName()
            }
            
            // In the future, we could maintain a navigation history to show actual folder names
            // For now, just show the depth level
            if components.count > 1 {
                breadcrumbs.append(contentsOf: Array(repeating: "Folder", count: components.count - 1))
            }
            
            return breadcrumbs.joined(separator: " > ")
        }
        
        // For iOS paths, show a more user-friendly representation
        if path.hasPrefix("ios://") || (path == "/" && fileService is iOSDeviceService) {
            if path == "ios://" || path.isEmpty || path == "/" {
                // Try to get actual device name
                if let iosService = fileService as? iOSDeviceService {
                    return iosService.getDeviceName()
                }
                return "iOS Device"
            }
            
            // For deeper paths, show the navigation trail
            let cleanPath = path.replacingOccurrences(of: "ios://", with: "")
            let components = cleanPath.split(separator: "/")
            if components.count <= 1 {
                // Try to get actual device name
                if let iosService = fileService as? iOSDeviceService {
                    return iosService.getDeviceName()
                }
                return "iOS Device"
            }
            
            // Show breadcrumbs: iOS Device > Folder1 > Folder2
            // Try to get actual device name
            var breadcrumbs = ["iOS Device"]
            if let iosService = fileService as? iOSDeviceService {
                breadcrumbs[0] = iosService.getDeviceName()
            }
            
            if components.count > 1 {
                breadcrumbs.append(contentsOf: Array(repeating: "Folder", count: components.count - 1))
            }
            
            return breadcrumbs.joined(separator: " > ")
        }
        
        return path
    }
    
    // MARK: - Performance Optimized Filtering/Sorting
    // Using cached version to avoid recomputing on every render
    var filteredAndSortedItems: [FileSystemItem] {
        return cachedFilteredItems
    }
    
    // Update the cached filtered items - call when items, search, or sort changes
    private func updateFilteredItems() {
        // Use regular Task to stay on MainActor - sorting is fast even for large lists
        Task { @MainActor in
            var result = items
            
            // Filter
            if !searchText.isEmpty {
                result = result.filter { $0.name.localizedCaseInsensitiveContains(searchText) }
            }
            
            // Sort - folders first, then by selected option
            result.sort { lhs, rhs in
                // Folders always first
                if lhs.isDirectory != rhs.isDirectory {
                    return lhs.isDirectory
                }
                
                switch sortOption {
                case .name:
                    let comparison = lhs.name.localizedStandardCompare(rhs.name)
                    return sortOrder == .ascending ? comparison == .orderedAscending : comparison == .orderedDescending
                case .kind:
                    return sortOrder == .ascending ? lhs.type.rawValue < rhs.type.rawValue : lhs.type.rawValue > rhs.type.rawValue
                case .dateModified:
                    return sortOrder == .ascending ? lhs.modificationDate < rhs.modificationDate : lhs.modificationDate > rhs.modificationDate
                case .dateCreated:
                    return sortOrder == .ascending ? lhs.creationDate < rhs.creationDate : lhs.creationDate > rhs.creationDate
                case .size:
                    return sortOrder == .ascending ? lhs.size < rhs.size : lhs.size > rhs.size
                }
            }
            
            cachedFilteredItems = result
        }
    }
    
    private func loadItems(forceRefresh: Bool = false) {
        // Set home path if not already set
        if homePath.isEmpty {
            homePath = currentPath
        }
        
        errorMessage = nil
        isLoading = true
        
        Task {
            do {
                // Only clear cache on force refresh (manual refresh button)
                // Normal navigation should use cached results when available
                if forceRefresh {
                    if let mtpService = fileService as? MTPService {
                        mtpService.clearCache()
                    }
                    if let iosService = fileService as? iOSDeviceService {
                        iosService.clearCache()
                    }
                }
                
                let newItems = try await fileService.listItems(at: currentPath)
                await MainActor.run {
                    self.items = newItems
                    self.isLoading = false
                    self.updateFilteredItems()
                }
            } catch {
                await MainActor.run {
                    self.errorMessage = "Error loading files: \(error.localizedDescription)"
                    self.items = []
                    self.cachedFilteredItems = []
                    self.isLoading = false
                }
            }
        }
    }
    
    private func navigate(to item: FileSystemItem) {
        if item.isDirectory {
            // Add current path to history before navigating
            addToHistory(currentPath)
            currentPath = item.path
            loadItems()
        }
    }
    
    private func navigateUp() {
        if currentPath.hasPrefix("mtp://") {
            // MTP Navigation using URL for proper path manipulation
            if let url = URL(string: currentPath) {
                let parent = url.deletingLastPathComponent()
                // Make sure we don't go above the mtp:// level
                if parent.absoluteString != "mtp:" && parent.absoluteString != "mtp:/" && parent.absoluteString != currentPath {
                    // Add current path to history before navigating
                    addToHistory(currentPath)
                    currentPath = parent.absoluteString
                    // Ensure path ends with / if needed
                    if !currentPath.hasSuffix("/") && currentPath != "mtp://" {
                        currentPath = currentPath + "/"
                    }
                    loadItems()
                } else if parent.absoluteString == "mtp:" || parent.absoluteString == "mtp:/" {
                    // Go back to root
                    // Add current path to history before navigating
                    addToHistory(currentPath)
                    currentPath = "mtp://"
                    loadItems()
                }
            }
        } else if currentPath.hasPrefix("ios://") || (currentPath == "/" && fileService is iOSDeviceService) {
            // iOS Navigation
            if currentPath == "ios://" || currentPath == "ios:///" || currentPath == "/" {
                // Already at root, can't go up
                return
            }
            
            // Remove trailing slash if present
            var cleanPath = currentPath
            if cleanPath.hasSuffix("/") && cleanPath != "ios://" && cleanPath != "ios:///" {
                cleanPath.removeLast()
            }
            
            // Remove last component
            if let lastSlashIndex = cleanPath.lastIndex(of: "/") {
                // Check if we're going above the ios:// level (index 5 is the position after "ios://")
                let iosPrefixEndIndex = cleanPath.index(cleanPath.startIndex, offsetBy: min(6, cleanPath.count))
                if lastSlashIndex >= iosPrefixEndIndex {
                    let parentPath = String(cleanPath[..<lastSlashIndex])
                    // Add current path to history before navigating
                    addToHistory(currentPath)
                    currentPath = parentPath.isEmpty ? "ios://" : parentPath
                    loadItems()
                } else {
                    // Go back to root
                    addToHistory(currentPath)
                    currentPath = "ios://"
                    loadItems()
                }
            } else {
                // Go back to root
                addToHistory(currentPath)
                currentPath = "ios://"
                loadItems()
            }
        } else {
            // Local file system
            let url = URL(fileURLWithPath: currentPath)
            let parent = url.deletingLastPathComponent()
            if parent.path != currentPath {
                // Add current path to history before navigating
                addToHistory(currentPath)
                currentPath = parent.path
                loadItems()
            }
        }
    }
    
    private func navigateHome() {
        if !homePath.isEmpty && currentPath != homePath {
            // Add current path to history before navigating
            addToHistory(currentPath)
            currentPath = homePath
            loadItems()
        }
    }
    
    private func navigateBack() {
        if canNavigateBack {
            // Move back in history
            currentHistoryIndex -= 1
            currentPath = navigationHistory[currentHistoryIndex]
            loadItems()
        }
    }
    
    private func navigateForward() {
        if canNavigateForward {
            // Move forward in history
            currentHistoryIndex += 1
            currentPath = navigationHistory[currentHistoryIndex]
            loadItems()
        }
    }
    
    private func addToHistory(_ path: String) {
        // Remove any forward history if we're not at the end
        if currentHistoryIndex < navigationHistory.count - 1 {
            navigationHistory.removeLast(navigationHistory.count - 1 - currentHistoryIndex)
        }
        
        // Add the new path to history
        navigationHistory.append(path)
        currentHistoryIndex = navigationHistory.count - 1
    }
    
    // Helper function to determine if the error is related to Android connectivity
    private func isAndroidConnectionError(_ error: String) -> Bool {
        return error.contains("Could not connect") ||
        error.contains("Device not connected") ||
        error.contains("MTP") ||
        (currentPath.hasPrefix("mtp://") && items.isEmpty && error.contains("loading"))
    }

    // Helper function to determine if the error is related to iOS connectivity
    private func isIOSConnectionError(_ error: String) -> Bool {
        return error.contains("Could not connect") ||
        error.contains("Device not connected") ||
        error.contains("iOS") ||
        error.contains("Trust required") ||
        error.contains("Device locked") ||
        error.contains("Connection error") ||
        (currentPath.hasPrefix("ios://") && items.isEmpty && error.contains("loading"))
    }
    
    // Show file info sheet
    private func showFileInfo(for item: FileSystemItem) {
        selectedFileInfoItem = item
    }
    
    // Duplicate a file
    private func duplicateFile(_ item: FileSystemItem) {
        // TODO: Implement file duplication
        print("Duplicate file: \(item.name)")
    }
    
    // Delete a file
    private func deleteFile(_ item: FileSystemItem) {
        itemToDelete = item
        showingDeleteConfirmation = true
    }
    
    // Perform the actual file deletion
    private func performDelete(_ item: FileSystemItem) {
        Task {
            do {
                try await fileService.deleteItem(at: item.path)
                // Refresh the file list
                await MainActor.run {
                    loadItems()
                }
            } catch {
                await MainActor.run {
                    errorMessage = "Failed to delete file: \(error.localizedDescription)"
                }
            }
        }
    }
    
    // Handle double click on items
    private func handleDoubleClick(on item: FileSystemItem) {
        // For folders, navigate into them
        if item.isDirectory {
            navigate(to: item)
            return
        }
        
        // For all files, open them with the default application for preview
        openFileWithDefaultApp(item)
    }
    
    // Open a file with the default application
    private func openFileWithDefaultApp(_ item: FileSystemItem) {
#if DEBUG
        print("Opening file with default app: \(item.path)")
#endif
        
        if item.path.hasPrefix("mtp://") || item.path.hasPrefix("ios://") || fileService is iOSDeviceService {
            // For remote files (MTP/iOS), download to temp first then open
            downloadAndOpenRemoteFile(item)
        } else {
            // For local files, open directly
            let url = URL(fileURLWithPath: item.path)
            NSWorkspace.shared.open(url)
        }
    }
    
    // Download a remote file (MTP/iOS) and open it
    private func downloadAndOpenRemoteFile(_ item: FileSystemItem) {
        // Show loading indicator
        isLoading = true
        
        Task {
            do {
                // Create temp directory for preview files
                let tempDir = FileManager.default.temporaryDirectory.appendingPathComponent("OneSharePreview", isDirectory: true)
                try? FileManager.default.createDirectory(at: tempDir, withIntermediateDirectories: true)
                
                // Create destination path with original filename
                let destinationURL = tempDir.appendingPathComponent(item.name)
                
                // Remove existing file if present
                try? FileManager.default.removeItem(at: destinationURL)
                
                // Download the file
                try await fileService.downloadFile(at: item.path, to: destinationURL, size: item.size) { progress, status in
                    // Progress updates handled by download
                }
                
                // Open with default app on main thread
                await MainActor.run {
                    isLoading = false
                    NSWorkspace.shared.open(destinationURL)
                }
            } catch {
                await MainActor.run {
                    isLoading = false
                    errorMessage = "Failed to preview file: \(error.localizedDescription)"
                }
            }
        }
    }
    
    // Clipboard
    @Binding var clipboard: ClipboardItem?
    let onPaste: (String) -> Void // Callback when paste is triggered in this view
    
    // Selection Logic
    private func handleSelection(for item: FileSystemItem) {
        let modifiers = NSEvent.modifierFlags
        
        if modifiers.contains(.command) {
            // Toggle selection
            if selection.contains(item.id) {
                selection.remove(item.id)
            } else {
                selection.insert(item.id)
                lastSelectedId = item.id
            }
        } else if modifiers.contains(.shift), let lastId = lastSelectedId, let lastIndex = filteredAndSortedItems.firstIndex(where: { $0.id == lastId }), let currentIndex = filteredAndSortedItems.firstIndex(where: { $0.id == item.id }) {
            // Range selection
            let start = min(lastIndex, currentIndex)
            let end = max(lastIndex, currentIndex)
            let range = filteredAndSortedItems[start...end]
            for i in range {
                selection.insert(i.id)
            }
        } else {
            // Single selection
            selection = [item.id]
            lastSelectedId = item.id
        }
    }
    
    // Copy Selection
    private func copySelection() {
        let selectedItems = filteredAndSortedItems.filter { selection.contains($0.id) }
        guard !selectedItems.isEmpty else { return }
        
        clipboard = ClipboardItem(
            items: selectedItems,
            sourceService: fileService,
            isCut: false
        )
    }
    
    // State for file info sheet
    @State private var selectedFileInfoItem: FileSystemItem?
    
    // State for delete confirmation
    @State private var showingDeleteConfirmation = false
    @State private var itemToDelete: FileSystemItem?
    
    // Computed property for the header/toolbar
    private var headerView: some View {
        HStack(spacing: 16) {
            // Path / Title
            HStack(spacing: 8) {
                Text(title)
                    .font(.system(.headline, design: .rounded))
                    .foregroundStyle(.secondary)
                
                Image(systemName: "chevron.right")
                    .font(.system(size: 10, weight: .bold))
                    .foregroundStyle(.tertiary)
                
                Text(displayPath(currentPath))
                    .font(.system(.subheadline, design: .rounded))
                    .foregroundStyle(.primary)
                    .lineLimit(1)
                    .truncationMode(.middle)
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 8)
            .background(VisualEffectView(material: .headerView, blendingMode: .withinWindow))
            .clipShape(Capsule())
            
            Spacer()
            
            // Navigation Controls
            HStack(spacing: 0) {
                Button(action: navigateHome) {
                    Image(systemName: "house")
                        .font(.system(size: 14, weight: .semibold))
                        .frame(width: 32, height: 28)
                }
                .buttonStyle(.plain)
                .disabled(currentPath == homePath || (currentPath == "/" && !homePath.hasPrefix("mtp")) && !homePath.hasPrefix("ios"))
                .help("Home")
                
                Divider()
                    .frame(height: 16)

                Button(action: navigateUp) {
                    Image(systemName: "arrow.left")
                        .font(.system(size: 14, weight: .semibold))
                        .frame(width: 32, height: 28)
                }
                .buttonStyle(.plain)
                .disabled(!canNavigateUp)
                .help("Back")
                
                Divider()
                    .frame(height: 16)
                
                Button(action: navigateForward) {
                    Image(systemName: "arrow.right")
                        .font(.system(size: 14, weight: .semibold))
                        .frame(width: 32, height: 28)
                }
                .buttonStyle(.plain)
                .disabled(!canNavigateForward)
                .help("Forward")
                
                Divider()
                    .frame(height: 16)
                
                Button(action: { loadItems(forceRefresh: true) }) {
                    Image(systemName: "arrow.clockwise")
                        .font(.system(size: 14, weight: .semibold))
                        .frame(width: 32, height: 28)
                }
                .buttonStyle(.plain)
                .help("Refresh")
            }
            .background(VisualEffectView(material: .headerView, blendingMode: .withinWindow))
            .clipShape(Capsule())
            .overlay(
                Capsule()
                    .stroke(.white.opacity(0.1), lineWidth: 1)
            )
            
            // Search
            HStack {
                Image(systemName: "magnifyingglass")
                    .font(.system(size: 14))
                    .foregroundStyle(.secondary)
                
                TextField("Search", text: $searchText)
                    .textFieldStyle(.plain)
                    .font(.system(.body, design: .rounded))
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 6)
            .frame(width: 200)
            .background(VisualEffectView(material: .headerView, blendingMode: .withinWindow))
            .clipShape(Capsule())
            .overlay(
                Capsule()
                    .stroke(.white.opacity(0.1), lineWidth: 1)
            )
            
            // View Toggle & Sort
            HStack(spacing: 0) {
                Picker("View", selection: $isGridView) {
                    Image(systemName: "square.grid.2x2").tag(true)
                    Image(systemName: "list.bullet").tag(false)
                }
                .pickerStyle(.segmented)
                .labelsHidden()
                .frame(width: 80)
                
                SortingView(
                    sortOption: $sortOption,
                    sortOrder: $sortOrder
                )
                .frame(width: 30)
            }
            .padding(4)
            .background(VisualEffectView(material: .headerView, blendingMode: .withinWindow))
            .clipShape(Capsule())
            .overlay(
                Capsule()
                    .stroke(.white.opacity(0.1), lineWidth: 1)
            )
        }
        .padding(.horizontal)
        .padding(.vertical, 12)
    }
    
    // Computed property for the file content view
    private var fileContentView: some View {
        ScrollView {
            if let errorMessage = errorMessage {
                errorView(errorMessage: errorMessage)
            } else if items.isEmpty && errorMessage == nil {
                emptyStateView
            } else {
                fileItemsView
            }
        }
        .scrollContentBackground(.hidden) // Use hidden to allow window background to show through
        .onDrop(of: [.text, .item], isTargeted: nil) { providers in
            print("🔍 DROP: Received \(providers.count) providers")
            
            // First, check if this is an internal clipboard paste
            if clipboard != nil {
                print("🔍 DROP: Internal clipboard paste detected")
                onPaste(currentPath)
                return true
            }
            
            // Check if any provider can load a URL
            var hasLoadableURLs = false
            for provider in providers {
                print("🔍 DROP: Checking provider: \(provider)")
                print("🔍 DROP: Can load URL? \(provider.canLoadObject(ofClass: URL.self))")
                if provider.canLoadObject(ofClass: URL.self) {
                    hasLoadableURLs = true
                    break
                }
            }
            
            print("🔍 DROP: Has loadable URLs? \(hasLoadableURLs)")
            
            // If we have loadable URLs, load them asynchronously
            if hasLoadableURLs {
                print("🔍 DROP: Starting async file load...")
                Task {
                    var fileURLs: [URL] = []
                    
                    // Load all file URLs
                    await withTaskGroup(of: URL?.self) { group in
                        for provider in providers {
                            if provider.canLoadObject(ofClass: URL.self) {
                                group.addTask {
                                    await withCheckedContinuation { continuation in
                                        _ = provider.loadObject(ofClass: URL.self) { url, error in
                                            print("🔍 DROP: Loaded URL: \(url?.path ?? "nil"), error: \(error?.localizedDescription ?? "none")")
                                            continuation.resume(returning: url)
                                        }
                                    }
                                }
                            }
                        }
                        
                        for await url in group {
                            if let url = url {
                                fileURLs.append(url)
                            }
                        }
                    }
                    
                    print("🔍 DROP: Loaded \(fileURLs.count) file URLs")
                    
                    await MainActor.run {
                        if !fileURLs.isEmpty {
                            print("🔍 DROP: Starting transfer for \(fileURLs.count) files to \(currentPath)")
                            if fileURLs.count == 1 {
                                transferManager.startTransferFromURL(fileURLs[0], to: fileService, at: currentPath)
                            } else {
                                transferManager.startMultipleTransfers(fileURLs, to: fileService, at: currentPath)
                            }
                        } else {
                            print("🔍 DROP: No file URLs loaded!")
                        }
                    }
                }
                return true
            }
            
            print("🔍 DROP: Returning false - no loadable URLs found")
            return false
        }
        .contextMenu {
            if clipboard != nil {
                Button("Paste") {
                    onPaste(currentPath)
                }
            }
        }

    }
    
    private func errorView(errorMessage: String) -> some View {
        VStack(alignment: .leading, spacing: 16) {

            
        // Android-specific troubleshooting guidance
        if currentPath.hasPrefix("mtp://") && isAndroidConnectionError(errorMessage) {
            androidTroubleshootingView
        }
        
        // iOS-specific troubleshooting guidance
        // iOS-specific troubleshooting guidance
        if (currentPath.hasPrefix("ios://") || title == "iOS") && isIOSConnectionError(errorMessage) {
            iOSTroubleshootingView
        }
        
        Button("Retry") {
            loadItems()
        }
        .buttonStyle(.borderedProminent)
        .controlSize(.large)
    }
    .padding()
    .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
    
    private var androidTroubleshootingView: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                Text("Android Connection Guide")
                    .font(.title2)
                    .fontWeight(.bold)
                    .foregroundColor(.blue)
                    .padding(.bottom, 4)
                
                Group {
                    Text("Step 1: Mac Preparation (Crucial)")
                        .font(.headline)
                        .foregroundColor(.primary)
                    Text("• COMPLETELY QUIT these apps if they are running:\n  - Android File Transfer\n  - OpenMTP\n  - Preview\n  - Photos\n• These apps aggressively grab the USB connection and prevent One Share from connecting.")
                        .font(.body)
                        .foregroundColor(.secondary)
                        .fixedSize(horizontal: false, vertical: true)
                    
                    Divider()
                    
                    Text("Step 2: Android Setup")
                        .font(.headline)
                        .foregroundColor(.primary)
                    Text("• Unlock your phone.\n• Swipe down from the top to see notifications.\n• Tap the 'Charging via USB' notification.\n• Select 'File Transfer' / 'MTP' mode.")
                        .font(.body)
                        .foregroundColor(.secondary)
                        .fixedSize(horizontal: false, vertical: true)
                    
                    Divider()
                    
                    Text("Step 3: Advanced Debugging (If needed)")
                        .font(.headline)
                        .foregroundColor(.primary)
                    Text("• Go to Settings > About Phone > Tap 'Build Number' 7 times.\n• Go to Settings > System > Developer Options.\n• Enable 'USB Debugging'.\n• If a popup appears on your phone asking to 'Allow USB debugging?', tap 'Allow'.")
                        .font(.body)
                        .foregroundColor(.secondary)
                        .fixedSize(horizontal: false, vertical: true)
                    
                    Divider()
                    
                    Text("Step 4: Last Resort")
                        .font(.headline)
                        .foregroundColor(.primary)
                    Text("• Unplug the USB cable and plug it back in.\n• Try a different USB port or cable.\n• Restart your Mac and Android device.")
                        .font(.body)
                        .foregroundColor(.secondary)
                        .fixedSize(horizontal: false, vertical: true)
                }
            }
            .padding()
            .frame(maxWidth: .infinity, alignment: .leading)
        }
        .background(Color.blue.opacity(0.05))
        .cornerRadius(12)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    private var iOSTroubleshootingView: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                Text("iOS Connection Guide")
                    .font(.title2)
                    .fontWeight(.bold)
                    .foregroundColor(.blue)
                    .padding(.bottom, 4)
                
                Group {
                    Text("Step 1: Mac Preparation")
                        .font(.headline)
                        .foregroundColor(.primary)
                    Text("• Make sure you have iTunes or Finder installed (for iOS 13+).\n• Quit any other iOS device management apps.")
                        .font(.body)
                        .foregroundColor(.secondary)
                        .fixedSize(horizontal: false, vertical: true)
                    
                    Divider()
                    
                    Text("Step 2: iOS Setup")
                        .font(.headline)
                        .foregroundColor(.primary)
                    Text("• Unlock your iPhone/iPad.\n• Connect it to your Mac with a Lightning cable.\n• If prompted on your device, tap 'Trust This Computer'.")
                        .font(.body)
                        .foregroundColor(.secondary)
                        .fixedSize(horizontal: false, vertical: true)
                    
                    Divider()
                    
                    Text("Step 3: Unlock Device")
                        .font(.headline)
                        .foregroundColor(.primary)
                    Text("• If your device is locked with a passcode, unlock it.\n• Make sure you've tapped 'Trust' if prompted.")
                        .font(.body)
                        .foregroundColor(.secondary)
                        .fixedSize(horizontal: false, vertical: true)
                    
                    Divider()
                    
                    Text("Step 4: House Arrest (App Sandbox Access)")
                        .font(.headline)
                        .foregroundColor(.primary)
                    Text("• Some apps require special permissions to access their files.\n• If you're trying to access a specific app's files, make sure the app supports file sharing.")
                        .font(.body)
                        .foregroundColor(.secondary)
                        .fixedSize(horizontal: false, vertical: true)
                    
                    Divider()
                    
                    Text("Step 5: Last Resort")
                        .font(.headline)
                        .foregroundColor(.primary)
                    Text("• Unplug the USB cable and plug it back in.\n• Try a different USB port or cable.\n• Restart your Mac and iOS device.\n• Try unlocking and trusting again.")
                        .font(.body)
                        .foregroundColor(.secondary)
                        .fixedSize(horizontal: false, vertical: true)
                }
            }
            .padding()
            .frame(maxWidth: .infinity, alignment: .leading)
        }
        .background(Color.blue.opacity(0.05))
        .cornerRadius(12)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    private var emptyStateView: some View {
        VStack {
            if currentPath.hasPrefix("mtp://") {
                VStack(spacing: 20) {
                    if connectionState == .connectedLocked {
                        // Waiting for permission
                        Image(systemName: "lock.shield")
                            .font(.system(size: 48))
                            .foregroundStyle(.orange)
                            .symbolEffect(.pulse)
                        
                        VStack(spacing: 8) {
                            Text("Unlock Your Device")
                                .font(.title2)
                                .fontWeight(.bold)
                            
                            Text("Please unlock your Android device and tap 'Allow' on the USB debugging or file transfer prompt.")
                                .font(.body)
                                .foregroundStyle(.secondary)
                                .multilineTextAlignment(.center)
                                .frame(maxWidth: 300)
                        }
                        
                        Button("I've Allowed Access") {
                            Task {
                                if let mtpService = fileService as? MTPService {
                                    _ = await mtpService.reconnect()
                                }
                                loadItems()
                            }
                        }
                        .buttonStyle(.borderedProminent)
                        .controlSize(.large)
                        
                    } else {
                        // Connecting or Disconnected
                        ProgressView()
                            .scaleEffect(1.0)
                            .frame(width: 30, height: 30)
                        
                        Text("Connecting to Android device...")
                            .font(.headline)
                            .multilineTextAlignment(.center)
                        
                        Text("Make sure your device is connected and USB debugging is enabled")
                            .font(.subheadline)
                            .foregroundColor(.secondary)
                            .multilineTextAlignment(.center)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                }
                .frame(maxWidth: 300)
                .padding()
            } else if currentPath.hasPrefix("ios://") || (currentPath == "/" && fileService is iOSDeviceService) || title == "iOS" {
                VStack(spacing: 20) {
                    if connectionState == .connectedLocked {
                        // Check if it's trust required or just locked
                        let isTrustRequired = (fileService as? iOSDeviceService)?.connectionState == .connectedLocked
                        
                        if isTrustRequired {
                            // Trust required
                            Image(systemName: "hand.raised.fill")
                                .font(.system(size: 48))
                                .foregroundStyle(.orange)
                                .symbolEffect(.pulse)
                            
                            VStack(spacing: 8) {
                                Text("Trust This Computer")
                                    .font(.title2)
                                    .fontWeight(.bold)
                                
                                Text("Please tap 'Trust' on your iOS device when prompted.")
                                    .font(.body)
                                    .foregroundStyle(.secondary)
                                    .multilineTextAlignment(.center)
                                    .frame(maxWidth: 300)
                            }
                            
                            Button("I've Trusted This Computer") {
                                Task {
                                    loadItems()
                                }
                            }
                            .buttonStyle(.borderedProminent)
                            .controlSize(.large)
                        } else {
                            // Device locked
                            Image(systemName: "lock.shield")
                                .font(.system(size: 48))
                                .foregroundStyle(.orange)
                                .symbolEffect(.pulse)
                            
                            VStack(spacing: 8) {
                                Text("Unlock Your Device")
                                    .font(.title2)
                                    .fontWeight(.bold)
                                
                                Text("Please unlock your iOS device to continue.")
                                    .font(.body)
                                    .foregroundStyle(.secondary)
                                    .multilineTextAlignment(.center)
                                    .frame(maxWidth: 300)
                            }
                            
                            Button("I've Unlocked My Device") {
                                Task {
                                    loadItems()
                                }
                            }
                            .buttonStyle(.borderedProminent)
                            .controlSize(.large)
                        }
                    } else {
                        // Connecting or Disconnected
                        VStack(spacing: 20) {
                            Image(systemName: "iphone.gen3")
                                .font(.system(size: 48))
                                .foregroundStyle(.blue)
                                .symbolEffect(.pulse)
                            
                            Text("Connect iOS Device")
                                .font(.title2)
                                .fontWeight(.bold)
                            
                            VStack(alignment: .leading, spacing: 12) {
                                HStack {
                                    Image(systemName: "cable.connector")
                                        .frame(width: 24)
                                    Text("1. Connect via USB cable")
                                }
                                
                                HStack {
                                    Image(systemName: "lock.open")
                                        .frame(width: 24)
                                    Text("2. Unlock your device")
                                }
                                
                                HStack {
                                    Image(systemName: "hand.raised")
                                        .frame(width: 24)
                                    Text("3. Tap 'Trust' if prompted")
                                }
                            }
                            .font(.body)
                            .foregroundStyle(.secondary)
                            .padding()
                            .background(Color.secondary.opacity(0.1))
                            .cornerRadius(12)
                            
                            if connectionState == .connecting {
                                HStack {
                                    ProgressView()
                                        .scaleEffect(0.8)
                                    Text("Searching for device...")
                                        .font(.caption)
                                        .foregroundStyle(.secondary)
                                }
                            }
                        }
                    }
                }
                .frame(maxWidth: 300)
                .padding()
            } else {
                Text("No items found")
                    .font(.headline)
                    .foregroundColor(.secondary)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .contentShape(Rectangle()) // Make the whole area tappable
        .onTapGesture {
            // Allow user to manually retry by clicking anywhere
            loadItems()
        }
    }
    
    private var fileItemsView: some View {
        ScrollView {
            ZStack(alignment: .topLeading) {
                // Content (grid or list)
                Group {
                    if isGridView {
                        fileGridView
                    } else {
                        fileListView
                    }
                }
                
                // Marquee selection overlay
                if isDraggingMarquee {
                    marqueeRectangle
                }
            }
            .coordinateSpace(name: "marqueeSpace")
            .onPreferenceChange(ItemFramePreferenceKey.self) { frames in
                itemFrames = frames
            }
        }
        .contentShape(Rectangle())
        .onTapGesture {
            // Click on empty space deselects all
            if !selection.isEmpty {
                selection.removeAll()
            }
        }
        .gesture(
            DragGesture(minimumDistance: 10, coordinateSpace: .local)
                .onChanged { value in
                    handleMarqueeDrag(value: value, modifiers: NSEvent.modifierFlags)
                }
                .onEnded { _ in
                    finishMarqueeSelection()
                }
        )
    }
    
    private var fileGridView: some View {
        LazyVGrid(columns: [GridItem(.adaptive(minimum: 100))], spacing: 16) {
            ForEach(filteredAndSortedItems, id: \.id) { item in
                fileGridItem(item)
                    .id(item.id) // Stable identity for performance
            }
        }
        .padding()
        .animation(.none, value: cachedFilteredItems.count) // Reduce animation overhead
    }
    
    // Check if this is a remote file (MTP or iOS)
    private var isRemoteFileService: Bool {
        return currentPath.hasPrefix("mtp://") || 
               currentPath.hasPrefix("ios://") ||
               fileService is iOSDeviceService
    }
    
    private func fileGridItem(_ item: FileSystemItem) -> some View {
        let isSelected = selection.contains(item.id)
        
        return VStack(spacing: 6) {
            // Icon - simplified for performance
            if isRemoteFileService {
                IconHelper.sfSymbolIcon(for: item)
                    .resizable()
                    .aspectRatio(contentMode: .fit)
                    .frame(width: iconSize, height: iconSize)
                    .foregroundStyle(IconHelper.iconColor(for: item))
            } else {
                IconHelper.nativeIcon(for: item)
                    .resizable()
                    .aspectRatio(contentMode: .fit)
                    .frame(width: iconSize, height: iconSize)
            }
            
            Text(item.name)
                .font(.caption)
                .lineLimit(2)
                .multilineTextAlignment(.center)
        }
        .frame(width: 90)
        .padding(8)
        .background(isSelected ? Color.accentColor.opacity(0.2) : Color.clear, in: RoundedRectangle(cornerRadius: 10))
        .contentShape(Rectangle())
        .onTapGesture(count: 2) {
            handleDoubleClick(on: item)
        }
        .simultaneousGesture(TapGesture().onEnded {
            handleSelection(for: item)
        })
        .contextMenu {
            fileContextMenu(for: item)
        }
    }
    
    private var fileListView: some View {
        LazyVStack(spacing: 2) {
            ForEach(filteredAndSortedItems, id: \.id) { item in
                fileListItem(item)
                    .id(item.id) // Stable identity for performance
            }
        }
        .padding(.horizontal)
        .animation(.none, value: cachedFilteredItems.count)
    }
    
    private func fileListItem(_ item: FileSystemItem) -> some View {
        let isSelected = selection.contains(item.id)
        
        return HStack(spacing: 10) {
            // Icon - simplified
            if isRemoteFileService {
                IconHelper.sfSymbolIcon(for: item)
                    .resizable()
                    .aspectRatio(contentMode: .fit)
                    .frame(width: 20, height: 20)
                    .foregroundStyle(IconHelper.iconColor(for: item))
            } else {
                IconHelper.nativeIcon(for: item)
                    .resizable()
                    .aspectRatio(contentMode: .fit)
                    .frame(width: 20, height: 20)
            }
            
            Text(item.name)
                .font(.callout)
                .lineLimit(1)
            
            Spacer()
            
            Text(item.formattedSize)
                .font(.caption)
                .foregroundStyle(.secondary)
                .frame(width: 55, alignment: .trailing)
            
            Text(item.formattedDate)
                .font(.caption)
                .foregroundStyle(.secondary)
                .frame(width: 95, alignment: .trailing)
        }
        .padding(.vertical, 5)
        .padding(.horizontal, 10)
        .background(isSelected ? Color.accentColor.opacity(0.2) : Color.clear, in: RoundedRectangle(cornerRadius: 6))
        .contentShape(Rectangle())
        .onTapGesture(count: 2) {
            handleDoubleClick(on: item)
        }
        .simultaneousGesture(TapGesture().onEnded {
            handleSelection(for: item)
        })
        .contextMenu {
            fileContextMenu(for: item)
        }
    }
    
    // MARK: - Marquee Selection
    
    /// The normalized rectangle for the marquee selection (handles any drag direction)
    private var normalizedMarqueeRect: CGRect {
        let x = min(marqueeStart.x, marqueeEnd.x)
        let y = min(marqueeStart.y, marqueeEnd.y)
        let width = abs(marqueeEnd.x - marqueeStart.x)
        let height = abs(marqueeEnd.y - marqueeStart.y)
        return CGRect(x: x, y: y, width: width, height: height)
    }
    
    /// Semi-transparent selection rectangle view
    private var marqueeRectangle: some View {
        let rect = normalizedMarqueeRect
        return RoundedRectangle(cornerRadius: 4)
            .fill(Color.accentColor.opacity(0.15))
            .overlay(
                RoundedRectangle(cornerRadius: 4)
                    .stroke(Color.accentColor.opacity(0.6), lineWidth: 1)
            )
            .frame(width: rect.width, height: rect.height)
            .position(x: rect.midX, y: rect.midY)
            .allowsHitTesting(false)
    }
    
    /// Handle drag gesture for marquee selection
    private func handleMarqueeDrag(value: DragGesture.Value, modifiers: NSEvent.ModifierFlags) {
        // Start marquee if not already dragging
        if !isDraggingMarquee {
            isDraggingMarquee = true
            marqueeStart = value.startLocation
            
            // Store current selection for modifier key behavior
            if modifiers.contains(.shift) || modifiers.contains(.command) {
                selectionBeforeDrag = selection
            } else {
                selectionBeforeDrag = []
                selection = []
            }
        }
        
        // Update end point
        marqueeEnd = value.location
        
        // Calculate which items intersect the marquee
        updateMarqueeSelection(modifiers: modifiers)
    }
    
    /// Update selection based on which items intersect the marquee rectangle
    private func updateMarqueeSelection(modifiers: NSEvent.ModifierFlags) {
        let marqueeRect = normalizedMarqueeRect
        
        // Find items that intersect with marquee
        var intersectingIds: Set<UUID> = []
        for (id, frame) in itemFrames {
            if marqueeRect.intersects(frame) {
                intersectingIds.insert(id)
            }
        }
        
        // Apply selection based on modifier keys
        if modifiers.contains(.command) {
            // Cmd: Toggle selection
            var newSelection = selectionBeforeDrag
            for id in intersectingIds {
                if newSelection.contains(id) {
                    newSelection.remove(id)
                } else {
                    newSelection.insert(id)
                }
            }
            selection = newSelection
        } else if modifiers.contains(.shift) {
            // Shift: Add to selection
            selection = selectionBeforeDrag.union(intersectingIds)
        } else {
            // No modifier: Replace selection
            selection = intersectingIds
        }
    }
    
    /// Finish marquee selection when drag ends
    private func finishMarqueeSelection() {
        isDraggingMarquee = false
        marqueeStart = .zero
        marqueeEnd = .zero
        selectionBeforeDrag = []
    }
    
    @ViewBuilder
    private func fileContextMenu(for item: FileSystemItem) -> some View {
        Button("Copy") {
            // If this item is in the selection, copy all selected items
            // Otherwise, just copy this item
            if selection.contains(item.id) && selection.count > 1 {
                let selectedItems = filteredAndSortedItems.filter { selection.contains($0.id) }
                clipboard = ClipboardItem(items: selectedItems, sourceService: fileService, isCut: false)
            } else {
                clipboard = ClipboardItem(items: [item], sourceService: fileService, isCut: false)
            }
        }
        
        Button("Move") {
            // If this item is in the selection, move all selected items
            // Otherwise, just move this item
            if selection.contains(item.id) && selection.count > 1 {
                let selectedItems = filteredAndSortedItems.filter { selection.contains($0.id) }
                clipboard = ClipboardItem(items: selectedItems, sourceService: fileService, isCut: true)
            } else {
                clipboard = ClipboardItem(items: [item], sourceService: fileService, isCut: true)
            }
        }
        
        Button("Get Info") {
            showFileInfo(for: item)
        }
        
        if !item.isDirectory {
            Button("Duplicate") {
                duplicateFile(item)
            }
        }
        
        Button("Delete") {
            deleteFile(item)
        }
    }
    
    private func createItemProvider(for item: FileSystemItem) -> NSItemProvider {
        // Set clipboard for internal copy/paste
        // If this item is in the selection, include all selected items in clipboard
        DispatchQueue.main.async {
            if self.selection.contains(item.id) && self.selection.count > 1 {
                let selectedItems = self.filteredAndSortedItems.filter { self.selection.contains($0.id) }
                self.clipboard = ClipboardItem(items: selectedItems, sourceService: self.fileService, isCut: false)
            } else {
                self.clipboard = ClipboardItem(items: [item], sourceService: self.fileService, isCut: false)
            }
        }
        
        // Check if this is a remote file (MTP or iOS)
        let isRemoteFile = item.path.hasPrefix("mtp://") || 
                           (item.path.hasPrefix("/") && fileService is iOSDeviceService)
        
        if isRemoteFile {
            let itemProvider = NSItemProvider()
            
            // Fix: Set suggestedName without extension to prevent double extension
            // Finder will append the correct extension based on the type identifier
            let nameWithoutExtension = (item.name as NSString).deletingPathExtension
            itemProvider.suggestedName = nameWithoutExtension
            
            // Determine type identifier
            let typeIdentifier: String
            if let type = UTType(filenameExtension: (item.name as NSString).pathExtension) {
                typeIdentifier = type.identifier
            } else {
                typeIdentifier = UTType.data.identifier
            }
            
            // Register file representation
            // This allows us to download the file on demand when the user drops it
            itemProvider.registerFileRepresentation(forTypeIdentifier: typeIdentifier, visibility: .all, loadHandler: { completionHandler in
                let progress = Progress(totalUnitCount: 100)
                
                Task {
                    do {
                        // Notify TransferManager
                        await MainActor.run {
                            self.transferManager.startExternalTransfer(filename: item.name, totalSize: item.size)
                        }
                        
                        // Create a temporary file URL
                        let tempDir = FileManager.default.temporaryDirectory
                        let tempURL = tempDir.appendingPathComponent(item.name)
                        
                        // Remove existing file if any
                        try? FileManager.default.removeItem(at: tempURL)
                        
                        // Download the file
                        // We capture fileService explicitly
                        try await self.fileService.downloadFile(at: item.path, to: tempURL, size: item.size) { p, _ in
                            progress.completedUnitCount = Int64(p * 100)
                            
                            // Update TransferManager
                            Task { @MainActor in
                                self.transferManager.updateProgress(progress: p, status: "Copying \(item.name)...", totalSize: item.size)
                            }
                        }
                        
                        // Completion
                        Task { @MainActor in
                            await self.transferManager.finishExternalTransfer()
                        }
                        
                        // Call completion with the file URL
                        // coordinated: false means we are not using FileCoordination (it's a temp file)
                        completionHandler(tempURL, false, nil)
                    } catch {
                        print("Error downloading file for drag: \(error)")
                        
                        // Error handling
                        Task { @MainActor in
                            await self.transferManager.failExternalTransfer(error: error)
                        }
                        
                        completionHandler(nil, false, error)
                    }
                }
                
                return progress
            })
            
            return itemProvider
        } else {
            // Local file
            return NSItemProvider(contentsOf: URL(fileURLWithPath: item.path)) ?? NSItemProvider()
        }
    }
    
    var body: some View {
            VStack(spacing: 0) {
                headerView
                fileContentView
            }
            .background(.thickMaterial) // Ensure material background for the whole view
            .cornerRadius(16)
            .overlay(
                RoundedRectangle(cornerRadius: 16)
                    .stroke(.separator, lineWidth: 1) // Native separator color
            )
            .onAppear {
                loadItems()
                
                // Set up device connection monitoring for MTP services
                if let mtpService = fileService as? MTPService {
                    mtpService.onDeviceConnectionChange = { state in
                        DispatchQueue.main.async {
                            self.connectionState = state
                            
                            switch state {
                            case .connected:
                                if currentPath.hasPrefix("mtp://") {
                                    // Device connected and unlocked, refresh
                                    loadItems()
                                }
                            case .connectedLocked:
                                // Device connected but locked, UI will update via connectionState
                                if currentPath.hasPrefix("mtp://") {
                                    errorMessage = nil // Clear any previous errors
                                    items = [] // Clear items to show empty state
                                }
                            case .disconnected:
                                if currentPath.hasPrefix("mtp://") {
                                    items = []
                                    errorMessage = nil
                                }
                            case .connecting, .error:
                                break // No specific action needed
                            }
                        }
                    }
                }
                
                // Set up device connection monitoring for iOS services
                if let iosService = fileService as? iOSDeviceService {
                    iosService.onDeviceConnectionChange = { state in
                        DispatchQueue.main.async {
                            self.connectionState = state
                            
                            switch state {
                            case .connected:
                                if currentPath.hasPrefix("ios://") || currentPath == "/" {
                                    // Device connected and unlocked, refresh
                                    loadItems()
                                }
                            case .connectedLocked:
                                // Device connected but locked or trust required, UI will update via connectionState
                                if currentPath.hasPrefix("ios://") || currentPath == "/" {
                                    errorMessage = nil // Clear any previous errors
                                    items = [] // Clear items to show empty state
                                }
                            case .disconnected:
                                if currentPath.hasPrefix("ios://") || currentPath == "/" {
                                    items = []
                                    errorMessage = nil
                                }
                            case .connecting, .error:
                                break // No specific action needed
                            }
                        }
                    }
                }
            }
            .sheet(item: $selectedFileInfoItem) { item in
                FileInfoView(item: item)
            }
            .alert("Delete File", isPresented: $showingDeleteConfirmation) {
                Button("Cancel", role: .cancel) { }
                Button("Delete", role: .destructive) {
                    if let item = itemToDelete {
                        performDelete(item)
                    }
                }
            } message: {
                if let item = itemToDelete {
                    Text("Are you sure you want to delete \(item.name)? This action cannot be undone.")
                }
            }
            // Loading overlay for smooth UX
            .overlay {
                if isLoading {
                    ZStack {
                        Color.black.opacity(0.1)
                        VStack(spacing: 12) {
                            ProgressView()
                                .scaleEffect(1.5)
                            Text("Loading...")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                        .padding(24)
                        .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 12))
                    }
                    .transition(.opacity.animation(.easeInOut(duration: 0.15)))
                }
            }
            // Update filtered items when search or sort changes
            .onChange(of: searchText) { _, _ in
                updateFilteredItems()
            }
            .onChange(of: sortOption) { _, _ in
                updateFilteredItems()
            }
            .onChange(of: sortOrder) { _, _ in
                updateFilteredItems()
            }
            .background(keyboardShortcuts)
            
        }

    
    // Hidden buttons for keyboard shortcuts
    private var keyboardShortcuts: some View {
        VStack {
            Button("Copy") {
                copySelection()
            }
            .keyboardShortcut("c", modifiers: .command)
            .opacity(0)
            
            Button("Paste") {
                onPaste(currentPath)
            }
            .keyboardShortcut("v", modifiers: .command)
            .disabled(clipboard == nil)
            .opacity(0)
        }
        .frame(width: 0, height: 0)
    }
    
    
    
}
