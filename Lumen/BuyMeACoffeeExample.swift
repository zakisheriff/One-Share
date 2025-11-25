import SwiftUI

// Example of how to integrate the Buy Me a Coffee button into the app
struct BuyMeACoffeeIntegrationExample: View {
    var body: some View {
        VStack(spacing: 30) {
            Text("Buy Me a Coffee Button Examples")
                .font(.title2)
                .fontWeight(.semibold)
            
            // Full button
            BuyMeACoffeeButton {
                // Handle the coffee purchase action
                openCoffeePurchaseURL()
            }
            
            // Icon-only version for toolbars
            HStack {
                Text("Toolbar version:")
                CoffeeIcon()
                    .onTapGesture {
                        openCoffeePurchaseURL()
                    }
                    .padding(8)
                    .background(.ultraThinMaterial)
                    .cornerRadius(6)
            }
            
            // In a toolbar context
            HStack {
                Text("In toolbar context:")
                Spacer()
                CoffeeIcon()
                    .onTapGesture {
                        openCoffeePurchaseURL()
                    }
            }
            .padding()
            .background(.ultraThinMaterial)
            .cornerRadius(8)
        }
        .padding()
        .frame(maxWidth: 400)
    }
    
    private func openCoffeePurchaseURL() {
        // In a real app, this would open the actual Buy Me a Coffee page
        #if DEBUG
        print("Opening Buy Me a Coffee URL...")
        #endif
    }
}

#Preview {
    BuyMeACoffeeIntegrationExample()
        .padding()
}