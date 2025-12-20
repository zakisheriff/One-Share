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
            LazyVGrid(columns: [GridItem(.adaptive(minimum: 140), spacing: 20)], spacing: 20) {
                ForEach(wirelessState.connectedPeers) { peer in
                    deviceCard(for: peer)
                }
            }
            .padding(24)
        }
    }
    
    private func deviceCard(for peer: Peer) -> some View {
        Button(action: {
            wirelessState.initiatePairing(with: peer)
            if !peer.isPaired {
                showingPairingSheet = true
            }
        }) {
            VStack(spacing: 12) {
                // Device icon with improved styling
                ZStack {
                    Circle()
                        .fill(.ultraThinMaterial)
                        .frame(width: 80, height: 80)
                        .shadow(color: .black.opacity(0.1), radius: 5, x: 0, y: 2)
                    
                    Image(systemName: peer.platform == "Android" ? "phone.fill" : "laptopcomputer") 
                        .font(.system(size: 36))
                        .symbolRenderingMode(.hierarchical)
                        .foregroundStyle(peer.isPaired ? .green : .blue)
                }
                
                VStack(spacing: 4) {
                    Text(peer.name)
                        .font(.system(size: 14, weight: .semibold))
                        .lineLimit(1)
                        .foregroundStyle(.primary)
                    
                    Text(peer.isPaired ? "Connected" : "Tap to Pair")
                        .font(.system(size: 11, weight: .medium))
                        .foregroundStyle(peer.isPaired ? .green : .secondary)
                }
            }
            .frame(width: 140, height: 160)
            .background(
                RoundedRectangle(cornerRadius: 20)
                    .fill(Color(nsColor: .controlBackgroundColor).opacity(0.6))
                    .shadow(color: .black.opacity(0.05), radius: 8, x: 0, y: 4)
            )
            .overlay(
                RoundedRectangle(cornerRadius: 20)
                    .stroke(peer.isPaired ? Color.green.opacity(0.3) : Color.white.opacity(0.1), lineWidth: 1)
            )
            // Hover effect handled by ButtonStyle in SwiftUI naturally, or we can add precise onHover
            .contentShape(Rectangle()) 
        }
        .buttonStyle(.plain)
        .contextMenu {
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
        VStack(spacing: 20) {
            ZStack {
                Circle()
                    .stroke(Color.blue.opacity(0.1), lineWidth: 4)
                    .frame(width: 120, height: 120)
                
                Circle()
                    .stroke(Color.blue.opacity(0.05), lineWidth: 4)
                    .frame(width: 200, height: 200)
                
                Image(systemName: "antenna.radiowaves.left.and.right")
                    .font(.system(size: 48))
                    .symbolEffect(.pulse.byLayer, options: .repeating)
                    .foregroundStyle(.blue.opacity(0.6))
            }
            .padding(.bottom, 10)
            
            Text("Searching for Devices...")
                .font(.title3)
                .fontWeight(.medium)
            
            Text("Ensure One Share is open on your Android device")
                .font(.subheadline)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
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
            .controlSize(.large)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
    
    // MARK: - Transfer Progress (Elegant Floating Panel)
    
    private var transferProgressView: some View {
        VStack(spacing: 16) {
            HStack {
                Image(systemName: "arrow.up.circle.fill") // Sending
                    .font(.title2)
                    .foregroundStyle(.blue)
                
                VStack(alignment: .leading, spacing: 2) {
                    Text("Sending File")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                    Text(wirelessState.currentTransferFileName)
                        .font(.body)
                        .fontWeight(.medium)
                        .lineLimit(1)
                }
                Spacer()
                Text("\(Int(wirelessState.transferProgress))%")
                    .font(.body)
                    .fontWeight(.bold)
                    .monospacedDigit()
            }
            
            ProgressView(value: wirelessState.transferProgress / 100)
                .progressViewStyle(.linear)
                .tint(.blue)
            
            HStack {
                Label(wirelessState.transferSpeed, systemImage: "speedometer")
                Spacer()
                Label(wirelessState.timeRemaining, systemImage: "timer")
            }
            .font(.caption)
            .foregroundStyle(.secondary)
        }
        .padding(20)
        .background(.regularMaterial) // Glass effect
        .clipShape(RoundedRectangle(cornerRadius: 16))
        .shadow(color: .black.opacity(0.15), radius: 10, x: 0, y: 5)
        .padding(32)
        .transition(.move(edge: .bottom).combined(with: .opacity))
    }
    
    // MARK: - Transfer Request (Elegant Notification)
    
    private var transferRequestView: some View {
        HStack(spacing: 20) {
            // Icon
            ZStack {
                Circle()
                    .fill(Color.blue.opacity(0.1))
                    .frame(width: 50, height: 50)
                Image(systemName: "arrow.down.doc.fill")
                    .font(.title3)
                    .foregroundStyle(.blue)
            }
            
            // Info
            VStack(alignment: .leading, spacing: 4) {
                Text("Incoming File")
                    .font(.headline)
                
                Text(wirelessState.pendingRequest?.fileName ?? "Unknown File")
                    .font(.subheadline)
                    .lineLimit(1)
                
                Text(formatBytes(wirelessState.pendingRequest?.fileSize ?? 0))
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            
            Spacer()
            
            // Actions
            HStack(spacing: 12) {
                Button(action: { wirelessState.declineTransfer() }) {
                    Image(systemName: "xmark")
                        .font(.system(size: 14, weight: .bold))
                        .foregroundStyle(.secondary)
                        .frame(width: 32, height: 32)
                        .background(Circle().fill(.gray.opacity(0.2)))
                }
                .buttonStyle(.plain)
                
                Button(action: { wirelessState.acceptTransfer() }) {
                    Image(systemName: "checkmark")
                        .font(.system(size: 14, weight: .bold))
                        .foregroundStyle(.white)
                        .frame(width: 32, height: 32)
                        .background(Circle().fill(Color.blue))
                }
                .buttonStyle(.plain)
            }
        }
        .padding(20)
        .background(.regularMaterial)
        .clipShape(RoundedRectangle(cornerRadius: 20))
        .overlay(
            RoundedRectangle(cornerRadius: 20)
                .stroke(.white.opacity(0.2), lineWidth: 1)
        )
        .shadow(color: .black.opacity(0.2), radius: 15, x: 0, y: 8)
        .padding(32)
        .transition(.move(edge: .top).combined(with: .opacity))
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
        VStack(spacing: 30) {
            if pairingManager.isPairing {
                // Show code to enter on other device
                VStack(spacing: 12) {
                    Image(systemName: "lock.laptopcomputer")
                        .font(.system(size: 40))
                        .foregroundStyle(.blue)
                    
                    Text("Enter this code on the other device")
                        .font(.headline)
                        .multilineTextAlignment(.center)
                }
                
                Text(pairingManager.pairingCode)
                    .font(.system(size: 48, weight: .bold, design: .monospaced))
                    .foregroundStyle(.primary)
                    .padding(20)
                    .background(
                        RoundedRectangle(cornerRadius: 12)
                            .fill(Color(nsColor: .controlBackgroundColor))
                    )
                    .textSelection(.enabled) // Allow copying
                
            } else if pairingManager.isInitiatingPairing {
                // Enter code from other device
                VStack(spacing: 12) {
                    Image(systemName: "key.fill")
                        .font(.system(size: 32))
                        .foregroundStyle(.blue)
                    
                    Text("Enter Pairing Code")
                        .font(.headline)
                }
                
                TextField("0000", text: $pairingManager.inputCode)
                    .textFieldStyle(.roundedBorder)
                    .font(.system(size: 32, weight: .semibold, design: .monospaced))
                    .multilineTextAlignment(.center)
                    .frame(width: 160)
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
                .controlSize(.large)
                .disabled(pairingManager.inputCode.count < 4)
                .keyboardShortcut(.defaultAction) // Enter key support for button
            }
            
            Button("Cancel") {
                pairingManager.reset()
                dismiss()
            }
            .buttonStyle(.borderless)
            .foregroundStyle(.secondary)
        }
        .padding(40)
        .frame(width: 350)
        .background(.ultraThinMaterial)
    }
}
