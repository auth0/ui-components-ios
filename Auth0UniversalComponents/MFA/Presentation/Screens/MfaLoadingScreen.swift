import SwiftUI

/// Centered spinner over the brand gradient. Leaving is the host's job (Back, or the sheet's Close).
public struct MfaLoadingScreen: View {
    let model: LoadingModel
    let messages: MfaMessages

    @Environment(\.auth0Theme) private var theme

    /// Creates the screen.
    ///
    /// - Parameters:
    ///   - model: What the screen renders.
    ///   - messages: The words to use.
    public init(model: LoadingModel, messages: MfaMessages = .default) {
        self.model = model
        self.messages = messages
    }

    /// The screen.
    public var body: some View {
        ZStack {
            theme.colors.background.layerBase.ignoresSafeArea()
            BrandGradient()
            MfaSpinner()
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .ignoresSafeArea(.keyboard)
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(messages.loading.accessibilityLabel)
    }
}

#Preview("Loading") {
    MfaLoadingScreen(model: LoadingModel())
}
