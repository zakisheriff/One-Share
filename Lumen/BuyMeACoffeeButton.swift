import SwiftUI

struct BuyMeACoffeeButton: View {
    var action: () -> Void = {}
    
    var body: some View {
        Button(action: action) {
            HStack(spacing: 6) {
                // Using SF Symbol for coffee cup
                Image(systemName: "cup.and.saucer.fill")
                    .foregroundColor(.brown)
                    .font(.system(size: 14))
                    .symbolRenderingMode(.multicolor)
                
                Text("Buy Me a Coffee")
                    .font(.system(size: 12, weight: .medium))
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 6)
        }
        .buttonStyle(BuyMeACoffeeButtonStyle())
        .accessibilityLabel("Support the developer with a coffee")
    }
}

// Simplified button style for better compatibility
struct BuyMeACoffeeButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .background(
                RoundedRectangle(cornerRadius: 6)
                    .fill(Color(nsColor: .controlColor))
                    .overlay(
                        RoundedRectangle(cornerRadius: 6)
                            .stroke(Color(nsColor: .gridColor), lineWidth: 0.5)
                    )
            )
            .scaleEffect(configuration.isPressed ? 0.95 : 1.0)
            .animation(.easeOut(duration: 0.1), value: configuration.isPressed)
    }
}

// Standalone coffee icon for toolbar/menu use
struct CoffeeIcon: View {
    var body: some View {
        Image(systemName: "cup.and.saucer.fill")
            .foregroundColor(.brown)
            .font(.system(size: 16))
            .symbolRenderingMode(.multicolor)
    }
}

struct BuyMeACoffeeButton_Previews: PreviewProvider {
    static var previews: some View {
        VStack(spacing: 20) {
            // Full button
            BuyMeACoffeeButton()
            
            // Dark mode
            BuyMeACoffeeButton()
                .preferredColorScheme(.dark)
            
            // Icon only for toolbar
            CoffeeIcon()
                .padding()
                .background(.ultraThinMaterial)
                .cornerRadius(6)
        }
        .padding()
        .background(Color.gray.opacity(0.1))
    }
}