//
//  SidebarView.swift
//  Lumen
//
//  Created by Zaki Sheriff on 2025-11-25.
//

import SwiftUI

struct SidebarView: View {
    @Binding var selectedCategory: String?
    @ObservedObject var deviceManager: DeviceManager
    
    var body: some View {
        List(selection: $selectedCategory) {
            Section("Views") {
                Label("Split Screen", systemImage: "square.split.2x1")
                    .tag("split")
                Label("Mac", systemImage: "desktopcomputer")
                    .tag("mac")
                Label("Android", systemImage: "phone.fill")
                    .tag("android")
                Label("iOS", systemImage: "iphone")
                    .tag("ios")
            }
            
            // Connected Devices Section
            if !deviceManager.connectedDevices.isEmpty {
                Section("Connected Devices") {
                    ForEach(deviceManager.connectedDevices) { device in
                        HStack {
                            switch device.type {
                            case .android:
                                Image(systemName: "phone.fill")
                                    .foregroundColor(.green)
                            case .ios:
                                Image(systemName: "iphone")
                                    .foregroundColor(.blue)
                            case .none:
                                Image(systemName: "questionmark")
                            }
                            
                            VStack(alignment: .leading) {
                                Text(device.name)
                                    .font(.body)
                                
                                HStack {
                                    switch device.connectionState {
                                    case .connected:
                                        Text("Ready")
                                            .font(.caption)
                                            .foregroundColor(.green)
                                        Circle()
                                            .fill(.green)
                                            .frame(width: 6, height: 6)
                                    case .connectedLocked:
                                        Text("Unlock Device")
                                            .font(.caption)
                                            .foregroundColor(.orange)
                                        Circle()
                                            .fill(.orange)
                                            .frame(width: 6, height: 6)
                                            .symbolEffect(.pulse)
                                    case .disconnected:
                                        Text("Not Connected")
                                            .font(.caption)
                                            .foregroundColor(.gray)
                                    case .connecting:
                                        Text("Connecting...")
                                            .font(.caption)
                                            .foregroundColor(.blue)
                                        ProgressView()
                                            .scaleEffect(0.5)
                                            .frame(width: 10, height: 10)
                                    case .error:
                                        Text("Connection Error")
                                            .font(.caption)
                                            .foregroundColor(.red)
                                    }
                                    
                                    Spacer()
                                }
                            }
                            
                            Spacer()
                        }
                        .tag(device.type == .android ? "android" : "ios")
                    }
                }
            }
        }
        .listStyle(.sidebar)
        .scrollContentBackground(.hidden)
        .font(.system(.body, design: .rounded))
        .frame(minWidth: 200)
    }
}

#Preview {
    SidebarView(selectedCategory: .constant("local"), deviceManager: DeviceManager(mtpService: nil, iosService: nil))
}