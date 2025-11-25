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
            Label("Split Screen", systemImage: "square.split.2x1")
                .tag("split")
            Label("Mac", systemImage: "desktopcomputer")
                .tag("mac")
            Label("Android", systemImage: "phone.fill")
                .tag("android")
        }
        .listStyle(SidebarListStyle())
        .frame(minWidth: 200)
    }
}

#Preview {
    SidebarView(selectedCategory: .constant("local"))
}
