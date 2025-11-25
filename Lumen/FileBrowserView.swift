//
//  FileBrowserView.swift
//  Lumen
//
//  Created by Zaki Sheriff on 2025-11-25.
//

import SwiftUI
import UniformTypeIdentifiers

enum SortOption: String, CaseIterable, Identifiable {
    case name = "Name"
    case date = "Date"
    case size = "Size"
    case kind = "Kind"
    
    var id: String { self.rawValue }
}

struct FileBrowserView: View {
    let title: String
    let fileService: FileService
    @State var currentPath: String
    
    @State private var items: [FileSystemItem] = []
    @State private var selection = Set<UUID>()
    @State private var errorMessage: String?
    
    @State private var isLoading = false
    
    // Finder Features State
    @State private var searchText = ""
    @State private var sortOption: SortOption = .name
    @State private var isGridView = false
    @State private var iconSize: CGFloat = 64
    
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
                return lhs.name.localizedStandardCompare(rhs.name) == .orderedAscending
            case .date:
                return lhs.modificationDate > rhs.modificationDate
            case .size:
                return lhs.size > rhs.size
            case .kind:
                return lhs.type.rawValue < rhs.type.rawValue
            }
        }
        
        return result
    }
    
    private func loadItems() {
        isLoading = true
        errorMessage = nil
        
        Task {
            do {
                let newItems = try await fileService.listItems(at: currentPath)
                await MainActor.run {
                    self.items = newItems
                    self.isLoading = false
                }
            } catch {
                await MainActor.run {
                    self.errorMessage = "Error loading files: \(error.localizedDescription)"
                    self.items = []
                    self.isLoading = false
                }
            }
        }
    }
    
    private func navigate(to item: FileSystemItem) {
        if item.isDirectory {
            currentPath = item.path
            loadItems()
        }
    }
    
    private func navigateUp() {
        if currentPath.hasPrefix("mtp://") {
            // MTP Navigation
            // Format: mtp://storageId/parentId
            // If parentId is root, go to mtp://
            
            let components = currentPath.replacingOccurrences(of: "mtp://", with: "").split(separator: "/")
            if components.count > 1 {
                // We are deep in structure. Go up one level.
                // But wait, MTP paths are ID based, not hierarchical in the string necessarily if we just append IDs.
                // Actually, in MTPService I constructed path as "mtp://storageId/fileId".
                // But `fileId` is the ID of the folder we are IN.
                // To go up, we need the parent ID of the current folder.
                // My current path structure "mtp://storageId/currentFolderId" doesn't encode the parent chain.
                // This is a problem with ID-based navigation if we don't store the stack or parent info.
                
                // However, `FileSystemItem` has `parentId`? No, it has `path`.
                // If I want to support "Up", I need to know the parent.
                // MTP `GetObjectInfo` gives parent ID.
                // But `FileBrowserView` only has the path string.
                
                // Option 1: Store path as full hierarchy "mtp://storage/rootId/folderId/subfolderId".
                // Option 2: Fetch parent ID from service when navigating up.
                // Option 3: Maintain a navigation stack in `FileBrowserView`.
                
                // Given `FileBrowserView` is generic, Option 1 is best if possible, but MTP IDs are unique, so hierarchy string is redundant but useful for "Up".
                // BUT, `MTPService` constructs the path.
                // If I change `MTPService` to build full paths, it might be complex.
                
                // Let's use a simpler approach for now:
                // If we are at "mtp://...", we can try to pop the last component if we treat it as a stack.
                // But `MTPService` only returns `mtp://storage/id`. It doesn't return the full chain.
                // So `navigateUp` is broken for MTP unless I fix `MTPService` or `FileBrowserView`.
                
                // Let's assume for now we just go back to root if we can't determine parent, OR we implement a stack.
                // Implementing a stack in `FileBrowserView` is a good UI pattern anyway.
                // But `FileBrowserView` is stateless regarding history currently (except `currentPath`).
                
                // Let's try to parse "mtp://" generic logic.
                // If I can't easily go up, I'll disable the button or just go to root.
                // For a robust solution, I should query the service for the parent.
                // But `FileService` protocol doesn't have `getParent(path)`.
                
                // Hack: For this task, I will just strip the last component.
                // If `MTPService` produces `mtp://storage/folderA/folderB`, then stripping works.
                // I need to ensure `MTPService` produces hierarchical paths.
                // Currently `MTPService` produces `mtp://storage/id`. This is NOT hierarchical.
                // It implies flat access by ID.
                
                // I will modify `MTPService` to try to support hierarchical paths if I can, OR
                // I will modify `FileBrowserView` to treat `mtp://` specially and maybe just go to root for now,
                // OR better, I'll add `parentPath` to `FileSystemItem`? No, `FileSystemItem` is fixed.
                
                // Let's look at `MTPService.swift` again.
                // It parses `mtp://storage/id`.
                // If I navigate to a folder, `MTPService` lists files in that folder.
                // The items returned have path `mtp://storage/childId`.
                // If I click a child folder, path becomes `mtp://storage/childId`.
                // The previous path was `mtp://storage/parentId`.
                // We lost the parentId.
                
                // I should change `MTPService` to append the ID to the current path!
                // `listItems(at path: String)` -> returns items.
                // If input path is `mtp://storage/parentId`, the items should have path `mtp://storage/parentId/childId`.
                // Then `navigateUp` works by stripping last component.
                // And `parsePath` needs to take the *last* component as the ID.
                
                // This seems like the correct fix. I will update `MTPService` first, then `FileBrowserView` logic will work (mostly).
                // `FileBrowserView` uses `URL` which handles `/` separation.
                // So I just need to make sure `MTPService` returns hierarchical paths.
                
                // Wait, I am in `FileBrowserView` update step.
                // I will update `FileBrowserView` to handle `mtp://` prefix for `URL` creation because `URL(fileURLWithPath:)` might prepend `file://`.
                // `URL(string:)` should be used for `mtp://`.
                
                if let url = URL(string: currentPath), url.scheme == "mtp" {
                     let parent = url.deletingLastPathComponent()
                     if parent.absoluteString != currentPath {
                         currentPath = parent.absoluteString
                         // Handle trailing slash if needed
                         if currentPath.hasSuffix("/") && currentPath != "mtp://" {
                             currentPath = String(currentPath.dropLast())
                         }
                         loadItems()
                     }
                } else {
                    // Local file system
                    let url = URL(fileURLWithPath: currentPath)
                    let parent = url.deletingLastPathComponent()
                    if parent.path != currentPath {
                        currentPath = parent.path
                        loadItems()
                    }
                }
            } else {
                 // Local file system
                let url = URL(fileURLWithPath: currentPath)
                let parent = url.deletingLastPathComponent()
                if parent.path != currentPath {
                    currentPath = parent.path
                    loadItems()
                }
            }
        }
    }
    
    // Clipboard
    @Binding var clipboard: ClipboardItem?
    let onPaste: (String) -> Void // Callback when paste is triggered in this view
    
    var body: some View {
        VStack(spacing: 0) {
            // Header / Breadcrumbs & Toolbar
            HStack {
                Text(title)
                    .font(.headline)
                    .foregroundStyle(.secondary)
                
                Text(currentPath)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
                    .truncationMode(.middle)
                
                Spacer()
                
                ControlGroup {
                    Button(action: navigateUp) {
                        Image(systemName: "arrow.up")
                    }
                    .disabled(currentPath == "/")
                    
                    Button(action: loadItems) {
                        Image(systemName: "arrow.clockwise")
                    }
                }
                
                // Search
                TextField("Search", text: $searchText)
                    .textFieldStyle(.roundedBorder)
                    .frame(width: 150)
                
                // Sort Menu
                Menu {
                    Picker("Sort By", selection: $sortOption) {
                        ForEach(SortOption.allCases) { option in
                            Text(option.rawValue).tag(option)
                        }
                    }
                } label: {
                    Image(systemName: "arrow.up.arrow.down")
                }
                .menuStyle(.borderlessButton)
                .frame(width: 30)
                
                // Paste Button
                if clipboard != nil {
                    Button(action: {
                        onPaste(currentPath)
                    }) {
                        Image(systemName: "doc.on.clipboard")
                    }
                    .help("Paste")
                    .buttonStyle(.borderedProminent)
                }
                
                // View Toggle
                Picker("View", selection: $isGridView) {
                    Image(systemName: "list.bullet").tag(false)
                    Image(systemName: "square.grid.2x2").tag(true)
                }
                .pickerStyle(.segmented)
                .frame(width: 90)
            }
            .padding()
            .background(.regularMaterial)
            
            if isLoading {
                ProgressView("Loading...")
                    .padding()
            } else if let error = errorMessage {
                Text(error)
                    .foregroundStyle(.red)
                    .padding()
            }
            
            // File Content
            ScrollView {
                if isGridView {
                    LazyVGrid(columns: [GridItem(.adaptive(minimum: 100))], spacing: 20) {
                        ForEach(filteredAndSortedItems) { item in
                            VStack {
    IconHelper.nativeIcon(for: item)
        .resizable()
        .aspectRatio(contentMode: .fit)
        .frame(width: iconSize, height: iconSize)
        .shadow(radius: 4, y: 2)
    
    Text(item.name)
        .font(.caption)
        .lineLimit(2)
        .multilineTextAlignment(.center)
}
.padding()
.background(selection.contains(item.id) ? Color.accentColor.opacity(0.2) : Color.clear)
.cornerRadius(8)
.hoverEffect()
.onTapGesture(count: 2) {
    navigate(to: item)
}
.onTapGesture {
    if selection.contains(item.id) {
        selection.remove(item.id)
    } else {
        selection = [item.id]
    }
}
.contextMenu {
    Button("Copy") {
        clipboard = ClipboardItem(item: item, sourceService: fileService, isCut: false)
    }
}
.onDrag {
    clipboard = ClipboardItem(item: item, sourceService: fileService, isCut: false)
    return NSItemProvider(object: item.path as NSString)
}
                        }
                    }
                    .padding()
                } else {
                    LazyVStack(spacing: 0) {
                        ForEach(filteredAndSortedItems) { item in
                            HStack {
    IconHelper.nativeIcon(for: item)
        .resizable()
        .aspectRatio(contentMode: .fit)
        .frame(width: 24, height: 24)
        .shadow(radius: 2, y: 1)
    
    VStack(alignment: .leading) {
        Text(item.name)
            .font(.body)
            .lineLimit(1)
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
.padding(.vertical, 4)
.padding(.horizontal)
.background(selection.contains(item.id) ? Color.accentColor.opacity(0.2) : Color.clear)
.contentShape(Rectangle())
.hoverEffect()
.onTapGesture(count: 2) {
    navigate(to: item)
}
.onTapGesture {
    selection = [item.id]
}
.contextMenu {
    Button("Copy") {
        clipboard = ClipboardItem(item: item, sourceService: fileService, isCut: false)
    }
}
.onDrag {
    clipboard = ClipboardItem(item: item, sourceService: fileService, isCut: false)
    return NSItemProvider(object: item.path as NSString)
}
                        }
                    }
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
        .background(.thickMaterial) // Ensure material background for the whole view
        .cornerRadius(12)
        .overlay(
            RoundedRectangle(cornerRadius: 12)
                .stroke(.separator, lineWidth: 1) // Native separator color
        )
        .onAppear {
            loadItems()
        }
    }
}

#Preview {
    FileBrowserView(
        title: "Local",
        fileService: MockFileService(items: [
            FileSystemItem(name: "Documents", path: "/Documents", size: 0, type: .folder, modificationDate: Date()),
            FileSystemItem(name: "Photo.jpg", path: "/Photo.jpg", size: 1024 * 1024 * 2, type: .image, modificationDate: Date())
        ]),
        currentPath: "/Documents",
        clipboard: .constant(nil),
        onPaste: { _ in }
    )
    .padding()
}
