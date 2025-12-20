//
//  WirelessTransferState.swift
//  One Share
//
//  Integrates One Share wireless transfer into One Share
//

import SwiftUI
import Combine

/// Manages wireless file transfer state for One Share
class WirelessTransferState: ObservableObject {
    // MARK: - Published Properties
    @Published var isEnabled: Bool = true // Always on by default
    @Published var connectedPeers: [Peer] = []
    @Published var isTransferring: Bool = false
    @Published var transferProgress: Double = 0.0
    @Published var currentTransferFileName: String = ""
    @Published var transferHistory: [TransferHistoryItem] = []
    @Published var transferSpeed: String = ""
    @Published var timeRemaining: String = ""
    @Published var pendingRequest: NetworkManager.TransferRequest?
    
    // MARK: - Managers
    let discoveryManager = DiscoveryManager()
    let networkManager = NetworkManager()
    let pairingManager = PairingManager()
    
    // MARK: - Private
    private var cancellables = Set<AnyCancellable>()
    
    init() {
        setupBindings()
        start() // Auto-start
    }
    
    private func setupBindings() {
        // Sync discovered peers
        discoveryManager.$discoveredPeers
            .receive(on: RunLoop.main)
            .assign(to: &$connectedPeers)
        
        // Update discovery manager when server starts
        networkManager.$serverIP.combineLatest(networkManager.$serverPort)
            .sink { [weak self] ip, port in
                if !ip.isEmpty && port != 0 {
                    self?.discoveryManager.updateConnectionInfo(ip: ip, port: port)
                }
            }
            .store(in: &cancellables)
        
        // Bind transfer state
        networkManager.$pendingRequest
            .receive(on: RunLoop.main)
            .assign(to: &$pendingRequest)
        
        networkManager.$transferProgress
            .receive(on: RunLoop.main)
            .assign(to: &$transferProgress)
        
        networkManager.$isTransferring
            .receive(on: RunLoop.main)
            .assign(to: &$isTransferring)
        
        networkManager.$currentTransferFileName
            .receive(on: RunLoop.main)
            .assign(to: &$currentTransferFileName)
        
        networkManager.$transferHistory
            .receive(on: RunLoop.main)
            .assign(to: &$transferHistory)
            
        networkManager.$transferSpeed
            .receive(on: RunLoop.main)
            .assign(to: &$transferSpeed)
            
        networkManager.$timeRemaining
            .receive(on: RunLoop.main)
            .assign(to: &$timeRemaining)
        
        // Handle pairing requests
        networkManager.onPairingRequest = { [weak self] code in
            guard let self = self else { return false }
            var result = false
            DispatchQueue.main.sync {
                result = self.pairingManager.verifyCode(code)
            }
            return result
        }
        
        networkManager.onPairingInitiated = { [weak self] ip, port in
            DispatchQueue.main.async {
                self?.pairingManager.generateCode()
                self?.pairingManager.setRemotePeer(ip: ip, port: port)
            }
        }
        
        // Add paired device to list
        pairingManager.$isAuthenticated
            .sink { [weak self] isAuthenticated in
                if isAuthenticated {
                    // Update pairing code UI
                    if let peer = self?.pairingManager.targetPeer, let ip = peer.ip, let port = peer.port {
                        // Mark current peer as paired if found
                        if let index = self?.connectedPeers.firstIndex(where: { $0.ip == ip }) {
                            self?.connectedPeers[index].isPaired = true
                        } else {
                            // Add manual peer if not found
                            self?.discoveryManager.addManualPeer(ip: ip, port: port, name: "Paired Device")
                        }
                    }
                }
            }
            .store(in: &cancellables)
        
        // Auto-accept from paired devices
        networkManager.shouldAutoAccept = { [weak self] in
            return self?.pairingManager.isAuthenticated ?? false
        }
    }
    
    // MARK: - Public API
    
    func start() {
        isEnabled = true
        networkManager.startServer()
        discoveryManager.startScanning()
        discoveryManager.startAdvertising()
    }
    
    func stop() {
        isEnabled = false
        networkManager.stopServer()
        discoveryManager.stopScanning()
        discoveryManager.stopAdvertising()
    }
    
    /// Send files to a peer
    func sendFiles(_ files: [URL], to peer: Peer) {
        guard let ip = peer.ip, let port = peer.port else {
            print("Peer has no connection info")
            return
        }
        
        for file in files {
            networkManager.sendFile(to: ip, port: port, url: file)
        }
    }
    
    /// Send files from FileSystemItems
    func sendItems(_ items: [FileSystemItem], to peer: Peer) {
        let urls = items.compactMap { item -> URL? in
            // Only send local files for now
            if !item.path.hasPrefix("mtp://") && !item.path.hasPrefix("ios://") {
                return URL(fileURLWithPath: item.path)
            }
            return nil
        }
        sendFiles(urls, to: peer)
    }
    
    /// Accept pending transfer request
    func acceptTransfer() {
        guard pendingRequest != nil else { return }
        networkManager.resolveRequest(accept: true)
    }
    
    /// Decline pending transfer request
    func declineTransfer() {
        guard pendingRequest != nil else { return }
        networkManager.resolveRequest(accept: false)
    }
    
    /// Initiate pairing with a peer
    func initiatePairing(with peer: Peer) {
        guard let ip = peer.ip, let port = peer.port else { return }
        
        // 1. Update UI State via PairingManager
        pairingManager.initiatePairing(with: peer)
        
        // 2. Send Network Request to Android to generate code
        networkManager.sendPairingRequest(to: ip, port: port) { [weak self] success in
            if !success {
                print("Failed to send pairing request to \(peer.name)")
                DispatchQueue.main.async {
                    self?.pairingManager.reset()
                }
            }
        }
    }
}
