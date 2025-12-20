//
//  SessionView.swift
//  One Share
//
//  Trusted session view for authenticated transfers
//
//

import SwiftUI
import UniformTypeIdentifiers

struct SessionView: View {
    @ObservedObject var wirelessState: WirelessTransferState
    
    var body: some View {
        VStack(spacing: 20) {
            // Header
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    Text("Trusted Session")
                        .font(.title2)
                        .fontWeight(.semibold)
                    
                    if let peer = wirelessState.pairingManager.targetPeer {
                        Text("Connected to \(peer.name)")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                }
                
                Spacer()
                
                Button("End Session") {
                    wirelessState.pairingManager.reset()
                    wirelessState.networkManager.cancelTransfer()
                }
                .buttonStyle(.bordered)
                .controlSize(.regular)
            }
            .padding(.horizontal)
            .padding(.top, 20)
            
            // Main Content Area
            VStack(spacing: 24) {
                // Drop Zone (Hero Area)
                dropZoneView
                
                // File History / Chat
                if !wirelessState.transferHistory.isEmpty {
                    VStack(alignment: .leading, spacing: 12) {
                        Text("Recent Transfers")
                            .font(.headline)
                            .padding(.horizontal)
                        
                        ScrollView {
                            LazyVStack(spacing: 12) {
                                ForEach(wirelessState.transferHistory) { item in
                                    TransferHistoryRow(item: item)
                                }
                            }
                            .padding(.horizontal)
                        }
                        .frame(maxHeight: 300)
                    }
                }
                
                Spacer()
            }
        }
        .background(Color(NSColor.windowBackgroundColor))
    }
    
    // MARK: - Drop Zone
    
    var dropZoneView: some View {
        Button(action: openFilePicker) {
            ZStack {
                RoundedRectangle(cornerRadius: 24)
                    .fill(.ultraThinMaterial)
                    .shadow(color: .black.opacity(0.05), radius: 10, x: 0, y: 5)
                
                RoundedRectangle(cornerRadius: 24)
                    .strokeBorder(style: StrokeStyle(lineWidth: 2, dash: [10]))
                    .foregroundStyle(.blue.accessability(brightness: 0.2)) // Subtle dashed line
                    .opacity(0.3)
                    .padding(1)
                
                VStack(spacing: 16) {
                    ZStack {
                        Circle()
                            .fill(Color.blue.opacity(0.1))
                            .frame(width: 80, height: 80)
                        
                        Image(systemName: "arrow.up.doc.fill")
                            .font(.system(size: 32))
                            .foregroundStyle(.blue)
                    }
                    
                    VStack(spacing: 4) {
                        Text("Drag & Drop Files")
                            .font(.title3)
                            .fontWeight(.medium)
                        
                        Text("or click to browse")
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                    }
                }
            }
            .frame(height: 200)
            .padding(.horizontal)
        }
        .buttonStyle(.plain)
        .onDrop(of: [.fileURL], isTargeted: nil) { providers in
            loadFiles(from: providers) { urls in
               sendUrls(urls)
            }
            return true
        }
    }
    
    // MARK: - Actions
    
    private func openFilePicker() {
        let panel = NSOpenPanel()
        panel.allowsMultipleSelection = true
        panel.canChooseDirectories = false
        panel.canChooseFiles = true
        
        if panel.runModal() == .OK {
            sendUrls(panel.urls)
        }
    }
    
    private func sendUrls(_ urls: [URL]) {
        if !urls.isEmpty {
             if let peer = wirelessState.pairingManager.targetPeer, let ip = peer.ip, let port = peer.port {
                 wirelessState.networkManager.sendFiles(urls: urls, to: ip, port: port)
            } else if let peer = wirelessState.connectedPeers.first(where: { $0.isPaired }), let ip = peer.ip, let port = peer.port {
                 wirelessState.networkManager.sendFiles(urls: urls, to: ip, port: port)
            }
        }
    }
    
    private func loadFiles(from providers: [NSItemProvider], completion: @escaping ([URL]) -> Void) {
        var urls: [URL] = []
        let group = DispatchGroup()
        
        for provider in providers {
            if provider.hasItemConformingToTypeIdentifier("public.file-url") {
                group.enter()
                provider.loadItem(forTypeIdentifier: "public.file-url", options: nil) { (item, error) in
                    if let data = item as? Data, let url = URL(dataRepresentation: data, relativeTo: nil) {
                        urls.append(url)
                    } else if let url = item as? URL {
                        urls.append(url)
                    }
                    group.leave()
                }
            }
        }
        
        group.notify(queue: .main) {
            completion(urls)
        }
    }
}

extension Color {
    func accessability(brightness: Double) -> Color {
        // Just a dummy helper or could use opacity. 
        // For now, returning self to prevent compile errors if we don't have Color extensions.
        // Actually, let's just use opacity in the call site or native modifiers.
        // I'll remove this usage to be safe.
        return self
    }
}

struct TransferHistoryRow: View {
    let item: TransferHistoryItem
    
    var body: some View {
        HStack(spacing: 16) {
            // Icon
            ZStack {
                Circle()
                    .fill(item.isIncoming ? Color.green.opacity(0.1) : Color.blue.opacity(0.1))
                    .frame(width: 40, height: 40)
                
                Image(systemName: item.isIncoming ? "arrow.down" : "arrow.up")
                    .font(.headline)
                    .foregroundStyle(item.isIncoming ? .green : .blue)
            }
            
            // Text
            VStack(alignment: .leading, spacing: 2) {
                Text(item.fileName)
                    .font(.body)
                    .fontWeight(.medium)
                    .lineLimit(1)
                
                HStack {
                    Text(item.isIncoming ? "Received" : "Sent")
                    if item.state == .completed {
                        Text("• Complete")
                    } else if item.state == .failed {
                        Text("• Failed")
                            .foregroundStyle(.red)
                    } else {
                        Text("• \(Int(item.progress))%")
                    }
                }
                .font(.caption)
                .foregroundStyle(.secondary)
            }
            
            Spacer()
            
            // Status Icon
            if item.state == .transferring {
                ProgressView(value: item.progress, total: 100)
                    .progressViewStyle(.circular)
                    .controlSize(.small)
            } else if item.state == .completed {
                Image(systemName: "checkmark.circle.fill")
                    .foregroundStyle(.secondary.opacity(0.5))
            }
        }
        .padding(12)
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(Color(nsColor: .controlBackgroundColor))
                .shadow(color: .black.opacity(0.05), radius: 2, x: 0, y: 1)
        )
    }
}
