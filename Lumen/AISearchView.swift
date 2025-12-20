//
//  AISearchView.swift
//  One Share
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
        .frame(width: 600, height: 500)
        .background(VisualEffectView(material: .popover, blendingMode: .withinWindow))
        .clipShape(RoundedRectangle(cornerRadius: 24, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 24, style: .continuous)
                .stroke(.white.opacity(0.2), lineWidth: 1)
        )
        .shadow(color: .black.opacity(0.3), radius: 30, x: 0, y: 15)
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
        VStack(spacing: 16) {
            HStack {
                Image(systemName: "sparkles")
                    .font(.system(size: 20, weight: .semibold))
                    .foregroundStyle(
                        LinearGradient(colors: [.purple, .blue], startPoint: .topLeading, endPoint: .bottomTrailing)
                    )
                    .symbolEffect(.pulse)
                
                Text("One Share AI")
                    .font(.system(.title3, design: .rounded))
                    .fontWeight(.semibold)
                
                Spacer()
                
                Button(action: onClose) {
                    Image(systemName: "xmark.circle.fill")
                        .font(.system(size: 22))
                        .foregroundStyle(.secondary.opacity(0.5))
                }
                .buttonStyle(.plain)

            }
            
            HStack(spacing: 12) {
                HStack {
                    Image(systemName: "magnifyingglass")
                        .foregroundStyle(.secondary)
                    
                    TextField("Ask One Share... (e.g., 'Photos from last week')", text: $query)
                        .textFieldStyle(.plain)
                        .font(.system(.body, design: .rounded))
                        .onSubmit {
                            performSearch()
                        }
                }
                .padding(12)
                .background(.white.opacity(0.1))
                .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
                .overlay(
                    RoundedRectangle(cornerRadius: 12, style: .continuous)
                        .stroke(isSearching ? Color.purple.opacity(0.5) : Color.white.opacity(0.1), lineWidth: 1)
                )
                
                if isSearching {
                    ProgressView()
                        .scaleEffect(0.8)
                        .frame(width: 32, height: 32)
                } else {
                    Button(action: performSearch) {
                        Image(systemName: "arrow.up.circle.fill")
                            .font(.system(size: 32))
                            .symbolRenderingMode(.hierarchical)
                            .foregroundStyle(
                                LinearGradient(colors: [.purple, .blue], startPoint: .topLeading, endPoint: .bottomTrailing)
                            )
                    }
                    .buttonStyle(.plain)
    
                }
            }
            
            HStack {
                Picker("", selection: $searchScope) {
                    ForEach(SearchScope.allCases) { scope in
                        Text(scope.rawValue).tag(scope)
                    }
                }
                .pickerStyle(.segmented)
                .labelsHidden()
                .frame(width: 200)
                
                Spacer()
                
                Button(action: { showApiKeyAlert = true }) {
                    HStack(spacing: 4) {
                        Image(systemName: "key.fill")
                            .font(.caption)
                        Text("API Key")
                            .font(.caption)
                    }
                    .padding(.horizontal, 8)
                    .padding(.vertical, 4)
                    .background(.white.opacity(0.1))
                    .clipShape(Capsule())
                }
                .buttonStyle(.plain)
            }
        }
        .padding(20)
        .background(VisualEffectView(material: .headerView, blendingMode: .withinWindow))
    }
    
    @ViewBuilder
    private var resultsArea: some View {
        if let error = errorMessage {
            VStack {
                Image(systemName: "exclamationmark.triangle.fill")
                    .font(.largeTitle)
                    .foregroundStyle(.orange)
                    .padding(.bottom, 8)
                Text(error)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
            }
            .padding()
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        } else if results.isEmpty && !isSearching {
            emptyStateView
        } else {
            resultsListView
        }
    }
    
    private var emptyStateView: some View {
        VStack(spacing: 20) {
            if query.isEmpty {
                Spacer()
                Image(systemName: "sparkles.rectangle.stack")
                    .font(.system(size: 64))
                    .foregroundStyle(
                        LinearGradient(colors: [.purple.opacity(0.5), .blue.opacity(0.5)], startPoint: .topLeading, endPoint: .bottomTrailing)
                    )
                
                VStack(spacing: 8) {
                    Text("Search your files with AI")
                        .font(.system(.title2, design: .rounded))
                        .fontWeight(.medium)
                    
                    Text("One Share scans your files locally and uses Gemini to find exactly what you need.")
                        .font(.system(.body, design: .rounded))
                        .foregroundStyle(.secondary)
                        .multilineTextAlignment(.center)
                        .frame(maxWidth: 300)
                }
                Spacer()
            } else {
                Spacer()
                Text("No matches found")
                    .font(.system(.title3, design: .rounded))
                    .foregroundStyle(.secondary)
                Spacer()
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
    
    private var resultsListView: some View {
        List(results, id: \.id) { (file: FileMetadata) in
            HStack(spacing: 12) {
                Image(systemName: file.type.iconName)
                    .font(.title2)
                    .foregroundStyle(.blue)
                    .frame(width: 40, height: 40)
                    .background(.blue.opacity(0.1))
                    .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
                
                VStack(alignment: .leading, spacing: 2) {
                    Text(file.name)
                        .font(.system(.body, design: .rounded))
                        .fontWeight(.medium)
                        .lineLimit(1)
                    
                    HStack(spacing: 6) {
                        Text(file.isRemote ? "Android" : "Mac")
                            .font(.system(size: 10, weight: .bold, design: .rounded))
                            .padding(.horizontal, 6)
                            .padding(.vertical, 2)
                            .background(file.isRemote ? Color.green.opacity(0.2) : Color.blue.opacity(0.2))
                            .foregroundStyle(file.isRemote ? Color.green : Color.blue)
                            .clipShape(Capsule())
                        
                        Text("•")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                        
                        Text(ByteCountFormatter.string(fromByteCount: file.size, countStyle: .file))
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                }
                
                Spacer()
                
                HStack(spacing: 0) {
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
                            items: [fileSystemItem],
                            sourceService: service,
                            isCut: false
                        )
                    }) {
                        Image(systemName: "doc.on.doc")
                            .font(.system(size: 14))
                            .frame(width: 28, height: 28)
                    }
                    .buttonStyle(.plain)
                    .help("Copy file")
    
                    
                    Button("Open") {
                        onOpen(file)
                    }
                    .buttonStyle(.bordered)
                    .controlSize(.small)
                    .clipShape(Capsule())
                }
            }
            .padding(.vertical, 8)
            .padding(.horizontal, 12)
            .listRowBackground(Color.clear)
            .listRowSeparator(.hidden)
            .background(
                RoundedRectangle(cornerRadius: 12, style: .continuous)
                    .fill(.white.opacity(0.05))
            )
            .padding(.horizontal, 16)
            .padding(.vertical, 4)
        }
        .listStyle(.plain)
        .scrollContentBackground(.hidden)
    }
    
    private var footerView: some View {
        HStack {
            if scanner.isScanning {
                ProgressView(value: scanner.scanProgress)
                    .frame(width: 100)
                    .tint(.purple)
                Text("Indexing files...")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            } else {
                Text("\(scanner.indexedFiles.count) files indexed")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            Spacer()
            
            Text("Powered by Gemini")
                .font(.caption2)
                .foregroundStyle(.secondary.opacity(0.5))
        }
        .padding(12)
        .background(VisualEffectView(material: .headerView, blendingMode: .withinWindow))
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
                        throw NSError(domain: "OneShare", code: 404, userInfo: [NSLocalizedDescriptionKey: "No files found to search. Please ensure you have files in Documents, Downloads, or Pictures."])
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
                     throw NSError(domain: "OneShare", code: 404, userInfo: [NSLocalizedDescriptionKey: "No files found in selected scope (\(searchScope.rawValue))."])
                }
                
                results = try await geminiService.search(query: query, files: scopedFiles)
            } catch {
                errorMessage = error.localizedDescription
            }
            isSearching = false
        }
    }
}
