import SwiftUI

/// What the user sees once an identifier is verified: a check, "Email verified." and what it means. Continue creates
/// the account.
struct SignupVerifiedScreen: View {
    let title: String
    let message: String
    let isLoading: Bool
    /// Shown above Continue, and read out when it appears.
    let errorMessage: String?
    let onContinue: () -> Void

    @Environment(\.auth0Theme) private var theme
    @Environment(\.colorScheme) private var colorScheme

    init(title: String, message: String, isLoading: Bool = false, errorMessage: String? = nil,
         onContinue: @escaping () -> Void) {
        self.title = title
        self.message = message
        self.isLoading = isLoading
        self.errorMessage = errorMessage
        self.onContinue = onContinue
    }

    // The check, title and message sit in the middle and Continue at the bottom, as the design places them.
    var body: some View {
        VStack(spacing: 0) {
            Spacer()
            VStack(spacing: theme.spacing.sm) {
                badge
                    .padding(.bottom, theme.spacing.xs)
                Text(title)
                    .auth0TextStyle(theme.typography.titleLarge)
                    .foregroundStyle(theme.colors.text.bold)
                    .accessibilityAddTraits(.isHeader)
                Text(message)
                    .auth0TextStyle(theme.typography.body)
                    .foregroundStyle(theme.colors.text.regular)
            }
            .multilineTextAlignment(.center)
            Spacer()
            if let errorMessage {
                LoginInlineError(errorMessage)
                    .padding(.bottom, theme.spacing.sm)
            }
            LoginPrimaryButton("Continue", isLoading: isLoading, action: onContinue)
        }
        .announcing(errorMessage)
        .embeddedScreenChrome(theme: theme, scrolls: true)
    }

    private var green: Color { theme.colors.foreground.success }

    private var badge: some View {
        ZStack {
            Circle()
                // The theme's success surface in light mode; in dark mode that is a bright mint, so a green tint.
                .fill(colorScheme == .dark ? green.opacity(0.18) : theme.colors.background.success)
            Circle()
                .strokeBorder(green.opacity(0.3), lineWidth: theme.sizes.borderWidth)
            Image(systemName: "checkmark.circle")
                .font(.system(size: theme.sizes.iconMedium, weight: .regular))
                .foregroundStyle(green)
        }
        .frame(width: theme.sizes.size3xlDimen, height: theme.sizes.size3xlDimen)
        .accessibilityHidden(true)
    }
}

#Preview("Verified") {
    SignupVerifiedScreen(title: "Email verified.", message: "Your email has been verified.") {}
}

#Preview("Verified – failed") {
    SignupVerifiedScreen(title: "Email verified.", message: "Your email has been verified.",
                         errorMessage: "We couldn't finish creating your account.") {}
}
