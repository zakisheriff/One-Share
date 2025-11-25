import SwiftUI

struct HoverEffect: ViewModifier {
    @State private var hovering = false
    func body(content: Content) -> some View {
        content
            .overlay(
                RoundedRectangle(cornerRadius: 6)
                    .fill(hovering ? Color.gray.opacity(0.2) : Color.clear)
            )
            .animation(.easeInOut(duration: 0.15), value: hovering)
            .onHover { inside in
                hovering = inside
            }
    }
}

extension View {
    func hoverEffect() -> some View {
        self.modifier(HoverEffect())
    }
}