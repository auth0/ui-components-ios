import SwiftUI

/// What the user sees once an identifier is verified: a check, "Email verified.", what comes next, and the way on.
/// Continue creates the account. Anything the server asks for first is collected before it.
struct SignupVerifiedScreen: View {
    let title: String
    let message: String
    let primaryTitle: String
    /// "Skip for now", when the next step is optional. `nil` shows only the primary button.
    let secondaryTitle: String?
    let isLoading: Bool
    /// Shown above the buttons, and read out when it appears.
    let errorMessage: String?
    let onPrimary: () -> Void
    let onSecondary: () -> Void

    @Environment(\.auth0Theme) private var theme
    @Environment(\.colorScheme) private var colorScheme

    init(title: String, message: String, primaryTitle: String = "Continue", secondaryTitle: String? = nil,
         isLoading: Bool = false, errorMessage: String? = nil, onPrimary: @escaping () -> Void,
         onSecondary: @escaping () -> Void = {}) {
        self.title = title
        self.message = message
        self.primaryTitle = primaryTitle
        self.secondaryTitle = secondaryTitle
        self.isLoading = isLoading
        self.errorMessage = errorMessage
        self.onPrimary = onPrimary
        self.onSecondary = onSecondary
    }

    // The check, title and message sit in the middle and the buttons at the bottom, as the design places them.
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
            LoginPrimaryButton(primaryTitle, isLoading: isLoading, action: onPrimary)
            if let secondaryTitle {
                LoginSecondaryButton(secondaryTitle, isEnabled: !isLoading, action: onSecondary)
                    .padding(.top, theme.spacing.sm)
            }
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

#Preview("Verified – phone next, optional") {
    SignupVerifiedScreen(title: "Email verified.",
                         message: "Your email has been verified. We will continue to ask for your phone number.",
                         primaryTitle: "Add your phone next", secondaryTitle: "Skip for now", onPrimary: {})
}

#Preview("Verified – failed") {
    SignupVerifiedScreen(title: "Email verified.", message: "Your email has been verified.",
                         errorMessage: "We couldn't finish creating your account.") {}
}
