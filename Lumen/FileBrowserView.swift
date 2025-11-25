//
//  FileBrowserView.swift
//  Lumen
//
//  Created by Zaki Sheriff on 2025-11-25.
//

import SwiftUI
import AppKit
import UniformTypeIdentifiers

// ... (rest of file)



struct FileBrowserView: View {
    let title: String
    let fileService: FileService
    @State var currentPath: String
    
    @State private var items: [FileSystemItem] = []
    @State private var selection = Set<UUID>()
    @State private var errorMessage: String?
    
    // Finder Features State
    @State private var searchText = ""
    @State private var sortOption: ExtendedSortOption = .name
    @State private var sortOrder: SortOrder = .ascending
    @State private var isGridView = false
    @State private var iconSize: CGFloat = 64
    
    // Navigation history
    @State private var navigationHistory: [String] = []
    @State private var currentHistoryIndex: Int = -1
    @State private var homePath: String = ""
    
    // Auto-refresh state
    @State private var isAutoRefreshing: Bool = false
    @State private var connectionState: MTPService.ConnectionState = .disconnected
    
    // Computed properties for path display and navigation
    private var canNavigateUp: Bool {
        // For local files, enable up button if not at root
        if !currentPath.hasPrefix("mtp://") {
            return currentPath != "/"
        }
        
        // For MTP, enable up button if we're not at the storage root
        // Format: mtp://storageId/fileId or deeper
        let cleanPath = currentPath.replacingOccurrences(of: "mtp://", with: "")
        let components = cleanPath.split(separator: "/")
        return components.count > 1
    }
    
    private var canNavigateBack: Bool {
        return currentHistoryIndex > 0
    }
    
    private var canNavigateForward: Bool {
        return currentHistoryIndex < navigationHistory.count - 1
    }
    
    private func displayPath(_ path: String) -> String {
        // For local files, return the path as is
        if !path.hasPrefix("mtp://") {
            return path
        }
        
        // For MTP paths, show a more user-friendly representation
        // Instead of showing the full path with IDs, show the title and indicate it's an Android device
        if path == "mtp://" || path.isEmpty || path == "/" {
            return "Android Device"
        }
        
        // For deeper paths, show the navigation trail
        let cleanPath = path.replacingOccurrences(of: "mtp://", with: "")
        let components = cleanPath.split(separator: "/")
        if components.count <= 1 {
            return "Android Device"
        }
        
        // Show breadcrumbs: Android Device > Folder1 > Folder2
        var breadcrumbs = ["Android Device"]
        // In the future, we could maintain a navigation history to show actual folder names
        // For now, just show the depth level
        if components.count > 1 {
            breadcrumbs.append(contentsOf: Array(repeating: "Folder", count: components.count - 1))
        }
        
        return breadcrumbs.joined(separator: " > ")
    }
    
    var filteredAndSortedItems: [FileSystemItem] {
        var result = items
        
        // Filter
        if !searchText.isEmpty {
            result = result.filter { $0.name.localizedCaseInsensitiveContains(searchText) }
        }
        
        // Sort
        result.sort { lhs, rhs in
            switch sortOption {
            case .name:
                let comparison = lhs.name.localizedStandardCompare(rhs.name)
                return sortOrder == .ascending ? comparison == .orderedAscending : comparison == .orderedDescending
            case .kind:
                if sortOrder == .ascending {
                    return lhs.type.rawValue < rhs.type.rawValue
                } else {
                    return lhs.type.rawValue > rhs.type.rawValue
                }
            case .dateModified:
                if sortOrder == .ascending {
                    return lhs.modificationDate < rhs.modificationDate
                } else {
                    return lhs.modificationDate > rhs.modificationDate
                }
            case .dateCreated:
                if sortOrder == .ascending {
                    return lhs.creationDate < rhs.creationDate
                } else {
                    return lhs.creationDate > rhs.creationDate
                }
            case .size:
                if sortOrder == .ascending {
                    return lhs.size < rhs.size
                } else {
                    return lhs.size > rhs.size
                }
            }
        }
        
        return result
    }
    
    private func loadItems() {
        // Set home path if not already set
        if homePath.isEmpty {
            homePath = currentPath
        }
        
        errorMessage = nil
        
        Task {
            do {
                // For MTP services, try to force a fresh connection
                if let mtpService = fileService as? MTPService {
                    // Clear cache to force fresh connection
                    mtpService.clearCache()
                }
                
                let newItems = try await fileService.listItems(at: currentPath)
                await MainActor.run {
                    self.items = newItems
                }
            } catch {
                await MainActor.run {
                    self.errorMessage = "Error loading files: \(error.localizedDescription)"
                    self.items = []
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
    
    // Show file info sheet
    private func showFileInfo(for item: FileSystemItem) {
        selectedFileInfoItem = item
        showingFileInfo = true
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
        
        // For media files, open them with the default application
        switch item.type {
        case .image, .video, .audio:
            openFileWithDefaultApp(item)
        default:
            // For other file types, navigate (which will show an error for non-folders)
            navigate(to: item)
        }
    }
    
    // Open a file with the default application
    private func openFileWithDefaultApp(_ item: FileSystemItem) {
#if DEBUG
        print("Opening file with default app: \(item.path)")
#endif
        
        if item.path.hasPrefix("mtp://") {
            // For MTP files, we need to download them first
            downloadAndOpenMTPFile(item)
        } else {
            // For local files, open directly
            let url = URL(fileURLWithPath: item.path)
            NSWorkspace.shared.open(url)
        }
    }
    
    // Download an MTP file and open it
    private func downloadAndOpenMTPFile(_ item: FileSystemItem) {
        // TODO: Implement MTP file download and opening
        print("Download and open MTP file: \(item.path)")
    }
    
    // Clipboard
    @Binding var clipboard: ClipboardItem?
    let onPaste: (String) -> Void // Callback when paste is triggered in this view
    
    // State for file info sheet
    @State private var showingFileInfo = false
    @State private var selectedFileInfoItem: FileSystemItem?
    
    // State for delete confirmation
    @State private var showingDeleteConfirmation = false
    @State private var itemToDelete: FileSystemItem?
    
    // Computed property for the header/toolbar
    private var headerView: some View {
        HStack {
            Text(title)
                .font(.headline)
                .foregroundStyle(.secondary)
            
            Text(displayPath(currentPath))
                .font(.caption)
                .foregroundStyle(.secondary)
                .lineLimit(1)
                .truncationMode(.middle)
            
            Spacer()
            
            // Navigation Controls with Apple-like styling
            HStack(spacing: 4) {
                Button(action: navigateHome) {
                    Image(systemName: "house")
                        .font(.system(size: 12, weight: .medium))
                        .frame(width: 20, height: 20)
                }
                .buttonStyle(.borderless)
                .disabled(currentPath == homePath)
                .help("Home")
                
                Button(action: navigateBack) {
                    Image(systemName: "arrow.left")
                        .font(.system(size: 12, weight: .medium))
                        .frame(width: 20, height: 20)
                }
                .buttonStyle(.borderless)
                .disabled(!canNavigateBack)
                .help("Back")
                
                Button(action: navigateForward) {
                    Image(systemName: "arrow.right")
                        .font(.system(size: 12, weight: .medium))
                        .frame(width: 20, height: 20)
                }
                .buttonStyle(.borderless)
                .disabled(!canNavigateForward)
                .help("Forward")
                
                Button(action: loadItems) {
                    Image(systemName: "arrow.clockwise")
                        .font(.system(size: 12, weight: .medium))
                        .frame(width: 20, height: 20)
                }
                .buttonStyle(.borderless)
                .help("Refresh")
            }
            .padding(.horizontal, 8)
            .padding(.vertical, 4)
            .background(.ultraThinMaterial)
            .cornerRadius(10)
            .overlay(
                RoundedRectangle(cornerRadius: 10)
                    .stroke(.separator, lineWidth: 0.5)
            )
            
            // Search with Apple-like styling
            TextField("Search", text: $searchText)
                .textFieldStyle(.plain)
                .padding(.horizontal, 8)
                .padding(.vertical, 6)
                .background(.ultraThinMaterial)
                .cornerRadius(10)
                .overlay(
                    RoundedRectangle(cornerRadius: 10)
                        .stroke(.separator, lineWidth: 0.5)
                )
                .frame(width: 180)
            
            // Sort Menu
            SortingView(
                sortOption: $sortOption,
                sortOrder: $sortOrder
            )
            
            // Paste Button
            if clipboard != nil {
                Button(action: {
                    onPaste(currentPath)
                }) {
                    Image(systemName: "doc.on.clipboard")
                        .font(.system(size: 12, weight: .medium))
                        .frame(width: 20, height: 20)
                }
                .buttonStyle(.borderless)
                .help("Paste")
            }
            
            // View Toggle with Apple-like styling
            Picker("View", selection: $isGridView) {
                Image(systemName: "list.bullet").tag(false)
                Image(systemName: "square.grid.2x2").tag(true)
            }
            .pickerStyle(.segmented)
            .frame(width: 100)
            .padding(4)
            .background(.ultraThinMaterial)
            .cornerRadius(10)
            .overlay(
                RoundedRectangle(cornerRadius: 10)
                    .stroke(.separator, lineWidth: 0.5)
            )
        }
        .padding(.horizontal)
        .padding(.horizontal)
        .padding(.vertical, 8)
        // .background(.ultraThinMaterial) // Removed to allow unified window background to show through
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
        .background(.background) // Use system background
        .onDrop(of: [.text], isTargeted: nil) { providers in
            if clipboard != nil {
                onPaste(currentPath)
                return true
            }
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
            Text("⚠️ Error")
                .font(.headline)
                .foregroundColor(.red)
            
            Text(errorMessage)
                .font(.body)
                .foregroundColor(.primary)
            
            // Android-specific troubleshooting guidance
            if currentPath.hasPrefix("mtp://") && isAndroidConnectionError(errorMessage) {
                androidTroubleshootingView
            }
            
            Button("Retry") {
                loadItems()
            }
            .buttonStyle(.borderedProminent)
        }
        .padding()
    }
    
    private var androidTroubleshootingView: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("📱 Android Device Connection Troubleshooting")
                .font(.headline)
                .foregroundColor(.blue)
            
            Text("1. Check USB Connection")
                .font(.headline)
                .foregroundColor(.secondary)
            
            Text("• Ensure your Android device is properly connected via USB cable\n• Try a different USB cable or port")
                .font(.body)
                .foregroundColor(.primary)
            
            Text("2. Enable Developer Options & USB Debugging")
                .font(.headline)
                .foregroundColor(.secondary)
            
            Text("• Go to Settings > About Phone/Tablet\n• Tap \"Build Number\" 7 times to enable Developer Options\n• Go back to Settings > Developer Options\n• Enable \"USB Debugging\"\n• On some devices: Enable \"USB debugging (Security settings)\"")
                .font(.body)
                .foregroundColor(.primary)
            
            Text("3. Allow Permission on Device")
                .font(.headline)
                .foregroundColor(.secondary)
            
            Text("• Unlock your Android device\n• Look for a notification asking for permission\n• Tap the notification and select \"Allow\" or \"OK\"\n• Some devices may show a dialog box on the screen - tap \"Allow\"")
                .font(.body)
                .foregroundColor(.primary)
            
            Text("4. Close Conflicting Applications")
                .font(.headline)
                .foregroundColor(.secondary)
            
            Text("• Close any other apps that might be accessing your device (e.g., Android File Transfer, Preview)\n• Restart this app after closing other apps")
                .font(.body)
                .foregroundColor(.primary)
            
            Text("5. Still Having Issues?")
                .font(.headline)
                .foregroundColor(.secondary)
            
            Text("• Try disconnecting and reconnecting your device\n• Restart both your computer and Android device\n• Ensure you have the latest device drivers installed")
                .font(.body)
                .foregroundColor(.primary)
        }
        .padding()
        .background(Color.blue.opacity(0.1))
        .cornerRadius(12)
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
        Group {
            if isGridView {
                fileGridView
            } else {
                fileListView
            }
        }
    }
    
    private var fileGridView: some View {
        LazyVGrid(columns: [GridItem(.adaptive(minimum: 100))], spacing: 20) {
            ForEach(filteredAndSortedItems) { item in
                fileGridItem(item)
            }
        }
        .padding()
    }
    
    private func fileGridItem(_ item: FileSystemItem) -> some View {
        VStack {
            IconHelper.nativeIcon(for: item)
                .resizable()
                .aspectRatio(contentMode: .fit)
                .frame(width: iconSize, height: iconSize)
                .shadow(radius: 2, y: 1)
            
            Text(item.name)
                .font(.caption)
                .lineLimit(2)
                .multilineTextAlignment(.center)
                .foregroundColor(.primary)
        }
        .padding(6)
        .background(
            ZStack {
                if selection.contains(item.id) {
                    RoundedRectangle(cornerRadius: 12, style: .continuous)
                        .fill(Color.accentColor.opacity(0.15))
                    
                    RoundedRectangle(cornerRadius: 12, style: .continuous)
                        .stroke(Color.accentColor.opacity(0.3), lineWidth: 1)
                }
            }
        )
        .cornerRadius(12)
        .hoverEffect()
        .onTapGesture(count: 2) {
            handleDoubleClick(on: item)
        }
        .simultaneousGesture(TapGesture().onEnded {
            if selection.contains(item.id) {
                selection.remove(item.id)
            } else {
                selection = [item.id]
            }
        })
        .contextMenu {
            fileContextMenu(for: item)
        }
        .onDrag {
            makeDragItem(for: item)
        }
    }
    
    private var fileListView: some View {
        LazyVStack(spacing: 0) {
            ForEach(filteredAndSortedItems) { item in
                fileListItem(item)
            }
        }
    }
    
    private func fileListItem(_ item: FileSystemItem) -> some View {
        HStack {
            IconHelper.nativeIcon(for: item)
                .resizable()
                .aspectRatio(contentMode: .fit)
                .frame(width: 24, height: 24)
                .shadow(radius: 1, y: 0.5)
            
            VStack(alignment: .leading) {
                Text(item.name)
                    .font(.body)
                    .lineLimit(1)
                    .foregroundColor(.primary)
            }
            
            Spacer()
            
            Text(item.formattedSize)
                .font(.subheadline)
                .foregroundStyle(.secondary)
                .frame(width: 70, alignment: .trailing)
            
            Text(item.formattedDate)
                .font(.subheadline)
                .foregroundStyle(.secondary)
                .frame(width: 120, alignment: .trailing)
        }
        .padding(.vertical, 6)
        .padding(.horizontal, 12)
        .background(
            ZStack {
                if selection.contains(item.id) {
                    RoundedRectangle(cornerRadius: 8, style: .continuous)
                        .fill(Color.accentColor.opacity(0.15))
                    
                    RoundedRectangle(cornerRadius: 8, style: .continuous)
                        .stroke(Color.accentColor.opacity(0.3), lineWidth: 1)
                }
            }
        )
        .contentShape(Rectangle())
        .hoverEffect()
        .onTapGesture(count: 2) {
            handleDoubleClick(on: item)
        }
        .simultaneousGesture(TapGesture().onEnded {
            selection = [item.id]
        })
        .contextMenu {
            fileContextMenu(for: item)
        }
        .onDrag {
            makeDragItem(for: item)
        }
    }
    
    @ViewBuilder
    private func fileContextMenu(for item: FileSystemItem) -> some View {
        Button("Copy") {
            clipboard = ClipboardItem(item: item, sourceService: fileService, isCut: false)
        }
        
        Button("Move") {
            clipboard = ClipboardItem(item: item, sourceService: fileService, isCut: true)
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
    
    private func makeDragItem(for item: FileSystemItem) -> NSItemProvider {
        clipboard = ClipboardItem(item: item, sourceService: fileService, isCut: false)
        if item.path.hasPrefix("mtp://") {
            let itemProvider = NSItemProvider()
            
            // Fix 1: Set the suggested name so Finder knows what to call it
            itemProvider.suggestedName = item.name
            
            // Determine correct type identifier
            let fileType: String
            if item.isDirectory {
                fileType = UTType.folder.identifier
            } else {
                fileType = UTType(filenameExtension: (item.name as NSString).pathExtension)?.identifier ?? "public.data"
            }
            
            let service = fileService
            itemProvider.registerFileRepresentation(forTypeIdentifier: fileType, fileOptions: [], visibility: .all) { completionHandler in
                _ = Task {
                    do {
                        let tempDir = FileManager.default.temporaryDirectory
                        let tempURL = tempDir.appendingPathComponent(item.name)
                        
                        // Clean up existing temp file if needed
                        try? FileManager.default.removeItem(at: tempURL)
                        
                        if let mtpService = service as? MTPService {
                            if item.isDirectory {
                                // Fix 2: Handle folder download recursively
                                try await mtpService.downloadFolder(at: item.path, to: tempURL) { _, _ in }
                            } else {
                                try await mtpService.downloadFile(at: item.path, to: tempURL, size: item.size) { _, _ in }
                            }
                            // Completion handler expects: (URL?, Bool, Error?)
                            // Bool is 'coordinated'. We pass false for temp file.
                            completionHandler(tempURL, false, nil)
                        } else {
                            completionHandler(nil, false, NSError(domain: "Lumen", code: 1, userInfo: [NSLocalizedDescriptionKey: "MTP Service unavailable"]))
                        }
                    } catch {
                        completionHandler(nil, false, error)
                    }
                }
                
                // Return a Progress object if desired, or nil
                return nil
            }
            
            return itemProvider
        } else {
            return NSItemProvider(contentsOf: URL(fileURLWithPath: item.path)) ?? NSItemProvider(object: item.path as NSString)
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
                        }
                    }
                }
            }
        }
        .sheet(isPresented: $showingFileInfo) {
            if let item = selectedFileInfoItem {
                FileInfoView(item: item)
            }
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
        
    }
}


