//
//  FileInfoView.swift
//  One Share
//
//  Created by Zaki Sheriff on 2025-11-25.
//

import SwiftUI

struct FileInfoView: View {
    let item: FileSystemItem
    @Environment(\.dismiss) private var dismiss
    
    var body: some View {
        VStack(alignment: .leading, spacing: 20) {
            // Header with close button
            HStack {
                Spacer()
                Button(action: { dismiss() }) {
                    Image(systemName: "xmark.circle.fill")
                        .font(.system(size: 24))
                        .foregroundStyle(.secondary.opacity(0.7))
                }
                .buttonStyle(.plain)
                .help("Close")
            }
            
            HStack(spacing: 16) {
                IconHelper.nativeIcon(for: item)
                    .resizable()
                    .aspectRatio(contentMode: .fit)
                    .frame(width: 80, height: 80)
                    .shadow(color: .black.opacity(0.2), radius: 8, x: 0, y: 4)
                
                VStack(alignment: .leading, spacing: 4) {
                    Text(item.name)
                        .font(.system(.title2, design: .rounded))
                        .fontWeight(.semibold)
                    
                    Text(item.isDirectory ? "Folder" : item.type.rawValue.capitalized)
                        .font(.system(.body, design: .rounded))
                        .foregroundColor(.secondary)
                }
                
                Spacer()
            }
            .padding(.bottom, 8)
            
            Divider()
                .background(.white.opacity(0.1))
            
            VStack(alignment: .leading, spacing: 12) {
                InfoRow(label: "Kind", value: item.isDirectory ? "Folder" : item.type.rawValue.capitalized)
                
                InfoRow(label: "Size", value: item.formattedSize)
                
                InfoRow(label: "Created", value: item.creationDate.formatted(date: .long, time: .shortened))
                
                InfoRow(label: "Modified", value: item.modificationDate.formatted(date: .long, time: .shortened))
                
                InfoRow(label: "Path", value: item.path)
            }
            
            Spacer()
        }
        .padding(24)
        .frame(minWidth: 400, minHeight: 350)
        .background(VisualEffectView(material: .popover, blendingMode: .withinWindow))
        .navigationTitle("Get Info")
    }
}

struct InfoRow: View {
    let label: String
    let value: String
    
    var body: some View {
        HStack {
            Text(label + ":")
                .fontWeight(.medium)
                .foregroundColor(.secondary)
                .frame(width: 80, alignment: .leading)
            
            Text(value)
                .lineLimit(2)
                .truncationMode(.middle)
            
            Spacer()
        }
    }
}

#Preview {
    FileInfoView(item: FileSystemItem(
        name: "Sample File.jpg",
        path: "/Users/sample/Pictures/Sample File.jpg",
        size: 1024 * 1024 * 2,
        type: .image,
        modificationDate: Date(),
        creationDate: Date().addingTimeInterval(-86400) // 1 day ago
    ))
}