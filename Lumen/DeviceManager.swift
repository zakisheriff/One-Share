//
//  DeviceManager.swift
//  One Share
//
//  Created by [Your Name] on 2025-11-27.
//

import Foundation
import Combine

enum DeviceType {
    case android
    case ios
    case none
}

struct ConnectedDevice: Identifiable {
    let id = UUID()
    let type: DeviceType
    let name: String
    let connectionState: ConnectionState
    let service: FileService
}

class DeviceManager: ObservableObject {
    @Published var connectedDevices: [ConnectedDevice] = []
    
    private var mtpService: MTPService?
    private var iosService: iOSDeviceService?
    
    init(mtpService: MTPService?, iosService: iOSDeviceService?) {
        // Use provided services instead of creating new ones
        self.mtpService = mtpService
        self.iosService = iosService
        
        // Set up connection state observers
        setupObservers()
    }
    
    private func setupObservers() {
        // Observe MTP service connection changes
        if let mtp = mtpService {
            mtp.onDeviceConnectionChange = { [weak self] state in
                DispatchQueue.main.async {
                    self?.updateDeviceList()
                }
            }
        }
        
        // Observe iOS service connection changes
        if let ios = iosService {
            ios.onDeviceConnectionChange = { [weak self] state in
                DispatchQueue.main.async {
                    self?.updateDeviceList()
                }
            }
        }
    }
    
    private func updateDeviceList() {
        var devices: [ConnectedDevice] = []
        
        // Check Android device
        if let mtp = mtpService {
            let state = mtp.connectionState
            if state != .disconnected {
                let deviceName = mtp.getDeviceName().isEmpty ? "Android Device" : mtp.getDeviceName()
                let device = ConnectedDevice(
                    type: .android,
                    name: deviceName,
                    connectionState: state,
                    service: mtp
                )
                devices.append(device)
            }
        }
        
        // Check iOS device
        if let ios = iosService {
            let state = ios.connectionState
            if state != .disconnected {
                let deviceName = ios.getDeviceName().isEmpty ? "iOS Device" : ios.getDeviceName()
                let device = ConnectedDevice(
                    type: .ios,
                    name: deviceName,
                    connectionState: state,
                    service: ios
                )
                devices.append(device)
            }
        }
        
        connectedDevices = devices
    }
    
    func getDeviceService(for type: DeviceType) -> FileService? {
        switch type {
        case .android:
            return mtpService
        case .ios:
            return iosService
        case .none:
            return nil
        }
    }
}