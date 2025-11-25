import SwiftUI
import AppKit

// Extended sorting options to match macOS Finder
enum ExtendedSortOption: String, CaseIterable, Identifiable {
    case name = "Name"
    case kind = "Kind"
    case dateModified = "Date Modified"
    case dateCreated = "Date Created"
    case size = "Size"
    
    var id: String { self.rawValue }
    
    var systemImage: String {
        switch self {
        case .name:
            return "textformat"
        case .kind:
            return "tag"
        case .dateModified:
            return "pencil"
        case .dateCreated:
            return "plus"
        case .size:
            return "square.3.layers.3d.down.left"
        }
    }
}

// Sorting order direction
enum SortOrder {
    case ascending
    case descending
}

struct SortingView: View {
    @Binding var sortOption: ExtendedSortOption
    @Binding var sortOrder: SortOrder
    
    var body: some View {
        Menu {
            ForEach(ExtendedSortOption.allCases) { option in
                Button(action: {
                    if sortOption == option {
                        // Toggle sort order if same option is selected
                        sortOrder = sortOrder == .ascending ? .descending : .ascending
                    } else {
                        // Change to new option, default to ascending
                        sortOption = option
                        sortOrder = .ascending
                    }
                }) {
                    HStack {
                        Image(systemName: option.systemImage)
                            .foregroundColor(.secondary)
                            .frame(width: 20)
                        Text(option.rawValue)
                            .foregroundColor(.primary)
                            .font(.system(size: 12))
                        
                        Spacer()
                        
                        if sortOption == option {
                            Image(systemName: sortOrder == .ascending ? "arrow.up" : "arrow.down")
                                .foregroundColor(.accentColor)
                                .fontWeight(.bold)
                                .font(.system(size: 10))
                        }
                    }
                    .padding(.horizontal, 10)
                    .padding(.vertical, 6)
                }
                .buttonStyle(PlainButtonStyle())
            }
        } label: {
            HStack(spacing: 4) {
                Image(systemName: "arrow.up.arrow.down")
                    .foregroundColor(.secondary)
                    .font(.system(size: 11))
                Image(systemName: sortOrder == .ascending ? "arrow.up" : "arrow.down")
                    .font(.system(size: 8))
                    .foregroundColor(.secondary)
                    .offset(x: -1, y: -1)
            }
            .padding(.horizontal, 8)
            .padding(.vertical, 6)
            .background(.ultraThinMaterial)
            .cornerRadius(10)
            .overlay(
                RoundedRectangle(cornerRadius: 10)
                    .stroke(.separator, lineWidth: 0.5)
            )
        }
        .menuStyle(.borderlessButton)
        .fixedSize()
        .onHover { hovering in
            if hovering {
                NSCursor.pointingHand.push()
            } else {
                NSCursor.pop()
            }
        }
        .onDisappear {
            NSCursor.pop()
        }
    }
}

struct SortingView_Previews: PreviewProvider {
    @State static var sortOption: ExtendedSortOption = .name
    @State static var sortOrder: SortOrder = .ascending
    
    static var previews: some View {
        SortingView(
            sortOption: $sortOption,
            sortOrder: $sortOrder
        )
        .padding()
        .frame(width: 200, height: 100)
    }
}