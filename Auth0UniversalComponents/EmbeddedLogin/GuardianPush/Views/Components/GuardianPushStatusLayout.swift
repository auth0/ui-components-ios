import SwiftUI

/// Centered title and message with an optional action, for terminal and transient outcomes. No icon.
struct GuardianPushStatusLayout<Action: View>: View {
    let title: String
    let message: String
    @ViewBuilder let action: () -> Action

    @Environment(\.auth0Theme) private var theme

    var body: some View {
        VStack(spacing: 0) {
            Text(title)
                .auth0TextStyle(GuardianPushStyle.title)
                .foregroundStyle(theme.colors.text.bold)
                .accessibilityAddTraits(.isHeader)
            Text(message)
                .auth0TextStyle(theme.typography.helper)
                .foregroundStyle(theme.colors.text.regular)
                .padding(.top, GuardianPushStyle.outcomeMessageTop)
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
