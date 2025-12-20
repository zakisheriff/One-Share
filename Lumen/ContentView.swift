//
//  ContentView.swift
//  One Share
//
//  Created by Zaki Sheriff on 2025-11-25.
//

import SwiftUI

struct ContentView: View {
    @EnvironmentObject var deviceManager: DeviceManager
    
    var body: some View {
        MainView()
            .environmentObject(deviceManager)
    }
}

#Preview {
    ContentView()
        .environmentObject(DeviceManager(mtpService: nil, iosService: nil))
        .environmentObject(FileScanner(mtpService: MTPService()))
}