//
//  SidebarView.swift
//  Lumen
//
//  Created by Zaki Sheriff on 2025-11-25.
//

import SwiftUI

struct SidebarView: View {
    @Binding var selectedCategory: String?
    
    var body: some View {
        List(selection: $selectedCategory) {
            Section(header: Text("Devices")) {
                Label("Mac", systemImage: "desktopcomputer")
                    .tag("local")
                Label("Android", systemImage: "phone.fill")
                    .tag("remote")
            }
            
            Section(header: Text("Favorites")) {
                Label("Downloads", systemImage: "arrow.down.circle")
                    .tag("downloads")
                Label("Documents", systemImage: "doc")
                    .tag("documents")
                Label("Pictures", systemImage: "photo")
                    .tag("pictures")
            }
        }
        .listStyle(SidebarListStyle())
        .frame(minWidth: 200)
    }
}

#Preview {
    SidebarView(selectedCategory: .constant("local"))
}
