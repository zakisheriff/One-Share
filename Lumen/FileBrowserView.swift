//
//  FileBrowserView.swift
//  Lumen
//
//  Created by Zaki Sheriff on 2025-11-25.
//

import SwiftUI

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
        do {
            items = try fileService.listItems(at: currentPath)
            errorMessage = nil
        } catch {
            errorMessage = "Error loading files: \(error.localizedDescription)"
            items = []
        }
    }
    
    private func navigate(to item: FileSystemItem) {
        if item.isDirectory {
            currentPath = item.path
            loadItems()
        }
    }
    
    private func navigateUp() {
        let url = URL(fileURLWithPath: currentPath)
        let parent = url.deletingLastPathComponent()
        if parent.path != currentPath {
            currentPath = parent.path
            loadItems()
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
                
                Button(action: navigateUp) {
                    Image(systemName: "arrow.up")
                }
                .disabled(currentPath == "/")
                
                Button(action: loadItems) {
                    Image(systemName: "arrow.clockwise")
                }
                
                // Search
                TextField("Search", text: $searchText)
                    .textFieldStyle(RoundedBorderTextFieldStyle())
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
                
                // View Toggle
                Picker("View", selection: $isGridView) {
                    Image(systemName: "list.bullet").tag(false)
                    Image(systemName: "square.grid.2x2").tag(true)
                }
                .pickerStyle(.segmented)
                .frame(width: 90)
            }
            .padding()
            .background(Color(NSColor.controlBackgroundColor))
            .contextMenu {
                if clipboard != nil {
                    Button("Paste") {
                        onPaste(currentPath)
                    }
                }
            }
            
            if let error = errorMessage {
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
                                Image(systemName: item.type.iconName)
                                    .resizable()
                                    .aspectRatio(contentMode: .fit)
                                    .frame(width: iconSize, height: iconSize)
                                    .foregroundStyle(item.type == .folder ? .blue : .secondary)
                                
                                Text(item.name)
                                    .font(.caption)
                                    .lineLimit(2)
                                    .multilineTextAlignment(.center)
                            }
                            .padding()
                            .background(selection.contains(item.id) ? Color.accentColor.opacity(0.2) : Color.clear)
                            .cornerRadius(8)
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
                        }
                    }
                    .padding()
                } else {
                    LazyVStack(spacing: 0) {
                        ForEach(filteredAndSortedItems) { item in
                            HStack {
                                Image(systemName: item.type.iconName)
                                    .foregroundStyle(item.type == .folder ? .blue : .secondary)
                                    .font(.title3)
                                    .frame(width: 24)
                                
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
                            .background(selection.contains(item.id) ? Color.accentColor : Color.clear)
                            .contentShape(Rectangle())
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
                        }
                    }
                }
            }
            .background(Color(NSColor.textBackgroundColor))
        }
        .background(Color(NSColor.windowBackgroundColor))
        .cornerRadius(8)
        .overlay(
            RoundedRectangle(cornerRadius: 8)
                .stroke(Color(NSColor.separatorColor), lineWidth: 1)
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
        currentPath: "/Documents"
    )
    .padding()
}
