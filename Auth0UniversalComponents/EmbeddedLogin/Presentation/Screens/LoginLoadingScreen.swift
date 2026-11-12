import SwiftUI

/// Centered spinner over the brand gradient.
public struct LoginLoadingScreen: View {
    @Environment(\.auth0Theme) private var theme

    public init() {}

    public var body: some View {
        ZStack {
            theme.colors.background.layerBase.ignoresSafeArea()
            BrandGradient()
            // Keeps the spinner still while the keyboard animates.
            BrandSpinner()
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .ignoresSafeArea(.keyboard)
        }
    }
}

#Preview("Loading") { LoginLoadingScreen() }
