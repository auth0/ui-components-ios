import SwiftUI

/// The last screen of a sign-up: the brand's mark, "Your account is created", and Continue, which hands the app the
/// credentials. Its words come from the entry configuration (`EmbeddedEntryMessages`) and its mark from the theme's
/// brand. A failure to hand them over is a full-screen error, as anywhere else in the flow.
struct SignupCreatedScreen: View {
    let isLoading: Bool
    let onContinue: () -> Void

    @Environment(\.auth0Theme) private var theme
    @Environment(\.embeddedEntry) private var entry

    var body: some View {
        VStack(spacing: 0) {
            Spacer()
            VStack(spacing: theme.spacing.xs) {
                theme.brand.mark
                    .resizable()
                    .scaledToFit()
                    .frame(height: theme.sizes.markHeight)
                    .foregroundStyle(theme.colors.text.bold)
                    .padding(.bottom, theme.spacing.lg)
                    .accessibilityLabel(theme.brand.logoLabel)
                Text(entry.messages.accountCreatedTitle)
                    .auth0TextStyle(theme.typography.displayMedium)
                    .foregroundStyle(theme.colors.text.bold)
                    .accessibilityAddTraits(.isHeader)
                Text(entry.messages.accountCreatedMessage)
                    .auth0TextStyle(theme.typography.body)
                    .foregroundStyle(theme.colors.text.regular)
            }
            .multilineTextAlignment(.center)
            Spacer()
            LoginPrimaryButton("Continue", isLoading: isLoading, action: onContinue)
        }
        .embeddedScreenChrome(theme: theme, scrolls: true)
    }
}

#Preview("Account created") {
    SignupCreatedScreen(isLoading: false) {}
}
