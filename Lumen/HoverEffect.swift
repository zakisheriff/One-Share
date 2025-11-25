import SwiftUI

struct HoverEffect: ViewModifier {
    @State private var hovering = false
    func body(content: Content) -> some View {
        content
            .scaleEffect(hovering ? 1.08 : 1.0)
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
