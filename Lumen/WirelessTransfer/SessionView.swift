//
//  SessionView.swift
//  One Share
//
//  Trusted session view for authenticated transfers
//

import SwiftUI
import UniformTypeIdentifiers

struct SessionView: View {
    @ObservedObject var wirelessState: WirelessTransferState
    
    var body: some View {
        VStack(spacing: 0) {
            // Header
            HStack {
                Text("Trusted Session")
                    .font(.headline)
                Spacer()
                
                Button(action: {
                    let panel = NSOpenPanel()
                    panel.allowsMultipleSelection = true
                    panel.canChooseDirectories = false
                    panel.canChooseFiles = true
                    
                    if panel.runModal() == .OK {
                        let urls = panel.urls
                        if let peer = wirelessState.pairingManager.targetPeer, let ip = peer.ip, let port = peer.port {
                             wirelessState.networkManager.sendFiles(urls: urls, to: ip, port: port)
                        } else {
                            // Try to find a paired peer if targetPeer is missing
                            if let peer = wirelessState.connectedPeers.first(where: { $0.isPaired }), let ip = peer.ip, let port = peer.port {
                                wirelessState.networkManager.sendFiles(urls: urls, to: ip, port: port)
                            } else {
                                print("Error: No target peer for session")
                            }
                        }
                    }
                }) {
                    Label("Send Files", systemImage: "doc.badge.plus")
                }
                .buttonStyle(.borderedProminent)
                
                Button("End Session") {
                    wirelessState.pairingManager.reset()
                    wirelessState.networkManager.cancelTransfer()
                }
                .buttonStyle(.bordered)
            }
            .padding()
            .background(Color(NSColor.controlBackgroundColor))
            
            Divider()
            
            // File History / Chat
            ScrollView {
                LazyVStack(spacing: 12) {
                    ForEach(wirelessState.transferHistory) { item in
                        TransferHistoryRow(item: item)
                    }
                }
                .padding()
            }
            
            Divider()
            
            // Drop Zone
            ZStack {
                Rectangle()
                    .fill(Color.blue.opacity(0.1))
                    .frame(height: 100)
                
                VStack {
                    Image(systemName: "arrow.up.doc")
                    .font(.largeTitle)
                    .foregroundStyle(.blue)
                    Text("Drop files here to send instantly")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }
            .onDrop(of: [.fileURL], isTargeted: nil) { providers in
                loadFiles(from: providers) { urls in
                    if !urls.isEmpty {
                         if let peer = wirelessState.pairingManager.targetPeer, let ip = peer.ip, let port = peer.port {
                             wirelessState.networkManager.sendFiles(urls: urls, to: ip, port: port)
                        } else if let peer = wirelessState.connectedPeers.first(where: { $0.isPaired }), let ip = peer.ip, let port = peer.port {
                             wirelessState.networkManager.sendFiles(urls: urls, to: ip, port: port)
                        }
                    }
                }
                return true
            }
        }
        .background(Color(NSColor.windowBackgroundColor))
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

struct TransferHistoryRow: View {
    let item: TransferHistoryItem
    
    var body: some View {
        HStack {
            Image(systemName: item.isIncoming ? "arrow.down.circle.fill" : "arrow.up.circle.fill")
                .foregroundStyle(item.isIncoming ? .green : .blue)
                .font(.title2)
            
            VStack(alignment: .leading) {
                Text(item.fileName)
                    .fontWeight(.medium)
                Text(item.isIncoming ? "Received" : "Sent")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            
            Spacer()
            
            if item.state == .transferring {
                ProgressView(value: item.progress, total: 100)
                    .progressViewStyle(.linear)
                    .frame(width: 100)
            } else if item.state == .completed {
                Image(systemName: "checkmark.circle")
                    .foregroundStyle(.secondary)
            } else if item.state == .failed {
                 Image(systemName: "exclamationmark.circle")
                    .foregroundStyle(.red)
            }
        }
        .padding()
        .background(Color(NSColor.controlBackgroundColor))
        .cornerRadius(10)
    }
}
