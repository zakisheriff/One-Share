//
//  AISearchView.swift
//  Lumen
//
//  Created by Zaki Sheriff on 2025-11-25.
//

import SwiftUI

struct AISearchView: View {
    @ObservedObject var scanner: FileScanner
    @ObservedObject var geminiService: GeminiService
    
    enum SearchScope: String, CaseIterable, Identifiable {
        case all = "All"
        case mac = "Mac"
        case android = "Android"
        var id: String { self.rawValue }
    }

    @State private var searchScope: SearchScope = .all
    @Binding var clipboard: ClipboardItem?
    
    @State private var query: String = ""
    @State private var results: [FileMetadata] = []
    @State private var isSearching = false
    @State private var errorMessage: String?
    @State private var showApiKeyAlert = false
    @State private var apiKeyInput = ""
    
    var onOpen: (FileMetadata) -> Void
    var onClose: () -> Void
    
    var body: some View {
        VStack(spacing: 0) {
            headerView
            resultsArea
            footerView
        }
        .frame(width: 500, height: 600)
        .background(Color(nsColor: .windowBackgroundColor))
        .cornerRadius(16)
        .overlay(
            RoundedRectangle(cornerRadius: 16)
                .stroke(Color.white.opacity(0.2), lineWidth: 1)
        )
        .alert("Enter Gemini API Key", isPresented: $showApiKeyAlert) {
            SecureField("API Key", text: $apiKeyInput)
            Button("Save") {
                geminiService.apiKey = apiKeyInput
            }
            Button("Cancel", role: .cancel) {}
        } message: {
            Text("Your API key is stored locally and used only for search queries.")
        }
        .onAppear {
            apiKeyInput = geminiService.apiKey
            if scanner.indexedFiles.isEmpty {
                scanner.startScan()
            }
        }
    }
    
    private var headerView: some View {
        HStack {
            Button(action: onClose) {
                Image(systemName: "xmark.circle.fill")
                    .foregroundStyle(.secondary)
                    .font(.title2)
            }
            .buttonStyle(.plain)
            .padding(.trailing, 8)
            
            Image(systemName: "sparkles")
                .foregroundStyle(.purple)
                .font(.title2)
            
            TextField("Ask Lumen... (e.g., 'Photos from last week')", text: $query)
                .textFieldStyle(.plain)
                .font(.system(size: 16))
                .padding(12)
                .background(Color.white.opacity(0.1))
                .cornerRadius(10)
                .onSubmit {
                    performSearch()
                }
            
            Picker("", selection: $searchScope) {
                ForEach(SearchScope.allCases) { scope in
                    Text(scope.rawValue).tag(scope)
                }
            }
            .pickerStyle(.menu)
            .frame(width: 80)
            .padding(.leading, 4)
            
            if isSearching {
                ProgressView()
                    .scaleEffect(0.8)
            } else {
                Button(action: performSearch) {
                    Image(systemName: "arrow.up.circle.fill")
                        .font(.title2)
                        .foregroundStyle(.blue)
                }
                .buttonStyle(.plain)
            }
            
            Button(action: { showApiKeyAlert = true }) {
                Image(systemName: "key.fill")
                    .foregroundStyle(.secondary)
            }
            .buttonStyle(.plain)
            .help("Set Gemini API Key")
        }
        .padding()
        .background(.ultraThinMaterial)
    }
    
    @ViewBuilder
    private var resultsArea: some View {
        if let error = errorMessage {
            Text(error)
                .foregroundStyle(.red)
                .padding()
            Spacer()
        } else if results.isEmpty && !isSearching {
            emptyStateView
        } else {
            resultsListView
        }
    }
    
    private var emptyStateView: some View {
        Group {
            if query.isEmpty {
                VStack(spacing: 12) {
                    Spacer()
                    Image(systemName: "magnifyingglass.circle")
                        .font(.system(size: 48))
                        .foregroundStyle(.secondary.opacity(0.5))
                    Text("Search your files with AI")
                        .font(.title3)
                        .foregroundStyle(.secondary)
                    Text("Lumen scans your files locally and uses Gemini to find exactly what you need.")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .multilineTextAlignment(.center)
                        .frame(maxWidth: 300)
                    Spacer()
                }
            } else {
                ScrollView {
                    VStack(spacing: 16) {
                        Text("No matches found.")
                            .foregroundStyle(.secondary)
                            .font(.headline)
                        
                        // Debug Info Section
                        VStack(alignment: .leading, spacing: 8) {
                            Text("Debug Info")
                                .font(.caption)
                                .bold()
                                .foregroundStyle(.secondary)
                            
                            Group {
                                Text("Indexed Files: \(scanner.indexedFiles.count)")
                                if !scanner.indexedFiles.isEmpty {
                                    Text("Sample File: \(scanner.indexedFiles.first?.name ?? "None")")
                                }
                                Text("Last Response: \(geminiService.lastRawResponse.prefix(100))...")
                            }
                            .font(.caption2)
                            .foregroundStyle(.secondary)
                            .monospaced()
                        }
                        .padding()
                        .background(Color.black.opacity(0.05))
                        .cornerRadius(8)
                    }
                    .padding()
                }
                Spacer()
            }
        }
    }
    
    private var resultsListView: some View {
        List(results, id: \.id) { (file: FileMetadata) in
            HStack {
                Image(systemName: file.type.iconName)
                    .font(.title2)
                    .foregroundStyle(.blue)
                    .frame(width: 30)
                
                VStack(alignment: .leading) {
                    Text(file.name)
                        .font(.headline)
                    HStack {
                        Text(file.isRemote ? "Android" : "Mac")
                            .font(.caption2)
                            .padding(.horizontal, 6)
                            .padding(.vertical, 2)
                            .background(file.isRemote ? Color.green.opacity(0.2) : Color.blue.opacity(0.2))
                            .cornerRadius(4)
                        
                        Text(ByteCountFormatter.string(fromByteCount: file.size, countStyle: .file))
                            .font(.caption)
                            .foregroundStyle(.secondary)
                        
                        Text(file.modificationDate.formatted(date: .abbreviated, time: .shortened))
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                }
                
                Spacer()
                
                Button(action: {
                    // Copy logic
                    let fileSystemItem = FileSystemItem(
                        name: file.name,
                        path: file.path,
                        size: file.size,
                        type: file.type,
                        modificationDate: file.modificationDate
                    )
                    
                    let service: FileService = file.isRemote ? scanner.mtpService : scanner.localService
                    
                    clipboard = ClipboardItem(
                        item: fileSystemItem,
                        sourceService: service,
                        isCut: false
                    )
                }) {
                    Image(systemName: "doc.on.doc")
                }
                .buttonStyle(.borderless)
                .help("Copy file")
                .padding(.trailing, 8)
                
                Button("Open") {
                    onOpen(file)
                }
                .buttonStyle(.bordered)
                .controlSize(.small)
            }
            .padding(.vertical, 4)
        }
        .listStyle(.plain)
    }
    
    private var footerView: some View {
        HStack {
            if scanner.isScanning {
                ProgressView(value: scanner.scanProgress)
                    .frame(width: 100)
                Text("Indexing files...")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            } else {
                Text("\(scanner.indexedFiles.count) files indexed")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            Spacer()
        }
        .padding(8)
        .background(.ultraThinMaterial)
    }
    
    private func performSearch() {
        guard !query.isEmpty else { return }
        isSearching = true
        errorMessage = nil
        
        Task {
            do {
                // Ensure we have files
                if scanner.indexedFiles.isEmpty {
                    print("Index empty. Triggering scan...")
                    scanner.startScan()
                    
                    // Wait briefly for some files to appear (simple polling)
                    var attempts = 0
                    while scanner.indexedFiles.isEmpty && attempts < 10 {
                        try await Task.sleep(nanoseconds: 500_000_000) // 0.5s
                        attempts += 1
                    }
                    
                    if scanner.indexedFiles.isEmpty {
                        throw NSError(domain: "Lumen", code: 404, userInfo: [NSLocalizedDescriptionKey: "No files found to search. Please ensure you have files in Documents, Downloads, or Pictures."])
                    }
                }
                
                // Filter files based on scope
                let scopedFiles = scanner.indexedFiles.filter { file in
                    switch searchScope {
                    case .all: return true
                    case .mac: return !file.isRemote
                    case .android: return file.isRemote
                    }
                }
                
                if scopedFiles.isEmpty {
                     throw NSError(domain: "Lumen", code: 404, userInfo: [NSLocalizedDescriptionKey: "No files found in selected scope (\(searchScope.rawValue))."])
                }
                
                results = try await geminiService.search(query: query, files: scopedFiles)
            } catch {
                errorMessage = error.localizedDescription
            }
            isSearching = false
        }
    }
}
