//
//  WirelessTransferView.swift
//  One Share
//
//  UI for wireless file transfer between Mac and Android devices
//

import SwiftUI

struct WirelessTransferView: View {
    @ObservedObject var wirelessState: WirelessTransferState
    @Binding var selectedFilesToSend: [FileSystemItem]
    
    @State private var showingPairingSheet = false
    @State private var selectedPeer: Peer?
    
    var body: some View {
        VStack(spacing: 0) {
            if wirelessState.pairingManager.isAuthenticated {
                SessionView(wirelessState: wirelessState)
            } else {
                // Header with status
                headerView
                
                Divider()
                
                if wirelessState.isEnabled {
                    if wirelessState.connectedPeers.isEmpty {
                        emptyStateView
                    } else {
                        deviceGridView
                    }
                } else {
                    disabledStateView
                }
            }
            
            // Transfer progress overlay (Global)
            if wirelessState.isTransferring {
                transferProgressView
            }
            
            // Pending request overlay
            if wirelessState.pendingRequest != nil {
                transferRequestView
            }
        }
        .sheet(isPresented: $showingPairingSheet) {
            PairingSheetView(pairingManager: wirelessState.pairingManager, networkManager: wirelessState.networkManager)
        }
        .onChange(of: wirelessState.pairingManager.isPairing) { isPairing in
            if isPairing {
                showingPairingSheet = true
            }
        }
        .onChange(of: wirelessState.pairingManager.isAuthenticated) { isAuthenticated in
            if isAuthenticated {
                showingPairingSheet = false
            }
        }
        .onChange(of: showingPairingSheet) { isPresented in
            if !isPresented && !wirelessState.pairingManager.isAuthenticated {
                wirelessState.pairingManager.reset()
            }
        }
    }
    
    // MARK: - Header
    
    private var headerView: some View {
        HStack {
            VStack(alignment: .leading, spacing: 4) {
                Text("Wireless Transfer")
                    .font(.headline)
                
                HStack(spacing: 6) {
                    Circle()
                        .fill(wirelessState.isEnabled ? .green : .gray)
                        .frame(width: 8, height: 8)
                    
                    Text(wirelessState.isEnabled ? "Discoverable" : "Off")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }
            
            Spacer()
            
            // Toggle removed - Always On
        }
        .padding()
    }
    
    // MARK: - Device Grid
    
    private var deviceGridView: some View {
        ScrollView {
            LazyVGrid(columns: [GridItem(.adaptive(minimum: 120))], spacing: 16) {
                ForEach(wirelessState.connectedPeers) { peer in
                    deviceCard(for: peer)
                }
            }
            .padding()
        }
    }
    
    private func deviceCard(for peer: Peer) -> some View {
        Button(action: {
            if peer.isPaired {
                // Determine if we should select for sending or just show status?
                // Actually, UX request: "click the container and it should be clicked"
                // If paired, maybe select it? But existing logic is specific.
                // Request implies pairing flow: "no need to click pair, user must just click the container"
                // So if NOT paired, clicking container -> Pair.
                wirelessState.initiatePairing(with: peer)
                showingPairingSheet = true
            } else {
                wirelessState.initiatePairing(with: peer)
                showingPairingSheet = true
            }
        }) {
            VStack(spacing: 8) {
                // Device icon
                Image(systemName: peer.platform == "Android" ? "phone" : "laptopcomputer") // Native symbols
                    .font(.system(size: 40))
                    .symbolRenderingMode(.hierarchical) // Modern look
                    .foregroundStyle(.blue)
                
                Text(peer.name)
                    .font(.caption)
                    .fontWeight(.medium)
                    .lineLimit(2)
                    .multilineTextAlignment(.center)
            }
            .frame(width: 110, height: 110)
            .padding(8)
            .background(
                RoundedRectangle(cornerRadius: 12)
                    .fill(Color(nsColor: .controlBackgroundColor)) // Native background
                    .shadow(color: .black.opacity(0.1), radius: 2, x: 0, y: 1)
            )
            .overlay(
                RoundedRectangle(cornerRadius: 12)
                    .stroke(peer.isPaired ? Color.green.opacity(0.5) : Color.clear, lineWidth: 2)
            )
        }
        .buttonStyle(.plain) // Remove default button button style to make it look like a card
        .contextMenu { // Keep explicit actions available
             if peer.isPaired {
                 Button("Send Files") { sendFilesToPeer(peer) }
             } else {
                 Button("Pair") { 
                    wirelessState.initiatePairing(with: peer) 
                    showingPairingSheet = true
                 }
             }
        }
    }
    
    // MARK: - Empty/Disabled States
    
    private var emptyStateView: some View {
        VStack(spacing: 16) {
            Image(systemName: "antenna.radiowaves.left.and.right")
                .font(.system(size: 48))
                .foregroundStyle(.secondary)
            
            Text("Looking for devices...")
                .font(.headline)
            
            Text("Make sure One Share is running on your Android device")
                .font(.caption)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
            
            ProgressView()
                .scaleEffect(0.8)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .padding()
    }
    
    private var disabledStateView: some View {
        VStack(spacing: 16) {
            Image(systemName: "wifi.slash")
                .font(.system(size: 48))
                .foregroundStyle(.secondary)
            
            Text("Wireless Transfer is Off")
                .font(.headline)
            
            Text("Turn on to discover and transfer files to nearby Android devices")
                .font(.caption)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
            
            Button("Turn On") {
                wirelessState.start()
            }
            .buttonStyle(.borderedProminent)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .padding()
    }
    
    // MARK: - Transfer Progress
    
    private var transferProgressView: some View {
        VStack(spacing: 12) {
            Text(wirelessState.currentTransferFileName)
                .font(.headline)
                .lineLimit(1)
            
            ProgressView(value: wirelessState.transferProgress / 100)
                .progressViewStyle(.linear)
            
            Text("\(Int(wirelessState.transferProgress))%")
                .font(.caption)
                .foregroundStyle(.secondary)
            
            HStack(spacing: 12) {
                if !wirelessState.transferSpeed.isEmpty {
                    Label(wirelessState.transferSpeed, systemImage: "speedometer")
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                }
                
                if !wirelessState.timeRemaining.isEmpty {
                    Label(wirelessState.timeRemaining, systemImage: "clock")
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                }
            }
        }
        .padding()
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(.background)
                .shadow(radius: 4)
        )
        .padding()
    }
    
    // MARK: - Transfer Request
    
    private var transferRequestView: some View {
        VStack(spacing: 16) {
            if let request = wirelessState.pendingRequest {
                Image(systemName: "arrow.down.doc.fill")
                    .font(.system(size: 36))
                    .foregroundStyle(.blue)
                
                Text("Incoming File")
                    .font(.headline)
                
                Text(request.fileName)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                
                Text(formatBytes(request.fileSize))
                    .font(.caption2)
                    .foregroundStyle(.secondary)
                
                HStack(spacing: 16) {
                    Button("Decline") {
                        wirelessState.declineTransfer()
                    }
                    .buttonStyle(.bordered)
                    
                    Button("Accept") {
                        wirelessState.acceptTransfer()
                    }
                    .buttonStyle(.borderedProminent)
                }
            }
        }
        .padding()
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(.background)
                .shadow(radius: 4)
        )
        .padding()
    }
    
    // MARK: - Actions
    
    private func sendFilesToPeer(_ peer: Peer) {
        wirelessState.sendItems(selectedFilesToSend, to: peer)
    }
    
    private func formatBytes(_ bytes: Int64) -> String {
        let formatter = ByteCountFormatter()
        formatter.countStyle = .file
        return formatter.string(fromByteCount: bytes)
    }
}

// MARK: - Pairing Sheet

struct PairingSheetView: View {
    @ObservedObject var pairingManager: PairingManager
    @ObservedObject var networkManager: NetworkManager
    @Environment(\.dismiss) var dismiss
    @FocusState private var isFieldFocused: Bool
    
    var body: some View {
        VStack(spacing: 24) {
            if pairingManager.isPairing {
                // Show code to enter on other device
                Text("Enter this code on the other device")
                    .font(.headline)
                
                Text(pairingManager.pairingCode)
                    .font(.system(size: 48, weight: .bold, design: .monospaced))
                    .foregroundStyle(.blue)
                    .textSelection(.enabled) // Allow copying
                
            } else if pairingManager.isInitiatingPairing {
                // Enter code from other device
                Text("Enter code from device")
                    .font(.headline)
                
                TextField("0000", text: $pairingManager.inputCode)
                    .textFieldStyle(.roundedBorder)
                    .font(.system(size: 24, design: .monospaced))
                    .multilineTextAlignment(.center)
                    .frame(width: 120)
                    .focused($isFieldFocused) // Auto-focus
                    .onSubmit { // Enter key support
                        if pairingManager.inputCode.count >= 4 {
                            pairingManager.verifyRemoteCode(networkManager: networkManager) { success in
                                if success { dismiss() }
                            }
                        }
                    }
                    .onAppear {
                         isFieldFocused = true
                    }
                
                Button("Connect") {
                    pairingManager.verifyRemoteCode(networkManager: networkManager) { success in
                        if success {
                            dismiss()
                        }
                    }
                }
                .buttonStyle(.borderedProminent)
                .disabled(pairingManager.inputCode.count < 4)
                .keyboardShortcut(.defaultAction) // Enter key support for button
            }
            
            Button("Cancel") {
                pairingManager.reset()
                dismiss()
            }
            .buttonStyle(.bordered)
        }
        .padding(32)
        .frame(width: 300, height: 250)
    }
}
