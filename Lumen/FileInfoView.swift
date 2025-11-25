import SwiftUI

struct FileInfoView: View {
    let item: FileSystemItem
    
    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack {
                IconHelper.nativeIcon(for: item)
                    .resizable()
                    .aspectRatio(contentMode: .fit)
                    .frame(width: 64, height: 64)
                
                VStack(alignment: .leading) {
                    Text(item.name)
                        .font(.title2)
                        .fontWeight(.semibold)
                    
                    Text(item.isDirectory ? "Folder" : item.type.rawValue.capitalized)
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                }
                
                Spacer()
            }
            
            Divider()
            
            VStack(alignment: .leading, spacing: 8) {
                InfoRow(label: "Kind", value: item.isDirectory ? "Folder" : item.type.rawValue.capitalized)
                
                InfoRow(label: "Size", value: item.formattedSize)
                
                InfoRow(label: "Created", value: item.creationDate.formatted(date: .long, time: .shortened))
                
                InfoRow(label: "Modified", value: item.modificationDate.formatted(date: .long, time: .shortened))
                
                InfoRow(label: "Path", value: item.path)
            }
            
            Spacer()
        }
        .padding()
        .frame(minWidth: 400, minHeight: 300)
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