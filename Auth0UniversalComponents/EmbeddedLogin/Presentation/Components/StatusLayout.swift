import SwiftUI

/// Centered title and message with an optional action, for terminal and transient outcomes. No icon.
/// Shared by the login's outcome screens and the factor screens.
struct StatusLayout<Action: View>: View {
    let title: String
    let message: String
    @ViewBuilder let action: () -> Action

    @Environment(\.auth0Theme) private var theme

    var body: some View {
        VStack(spacing: 0) {
            Text(title)
                .auth0TextStyle(FactorScreenStyle.title)
                .foregroundStyle(theme.colors.text.bold)
                .accessibilityAddTraits(.isHeader)
            Text(message)
                .auth0TextStyle(theme.typography.helper)
                .foregroundStyle(theme.colors.text.regular)
                .padding(.top, FactorScreenStyle.outcomeMessageTop)
            action()
                .padding(.top, theme.spacing.md)
        }
        .multilineTextAlignment(.center)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .padding(.horizontal, theme.spacing.xl)
        // Sits slightly above center, as in the design.
        .padding(.bottom, theme.spacing.xl)
    }
}
