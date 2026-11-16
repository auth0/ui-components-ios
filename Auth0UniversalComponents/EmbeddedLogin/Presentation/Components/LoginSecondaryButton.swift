import SwiftUI

/// Full-width outlined button with an optional leading icon, e.g. "Continue with Phone". Sits under
/// `LoginPrimaryButton` and matches its shape. While `isLoading` a spinner takes the place of the title and icon, and
/// the button keeps its size.
struct LoginSecondaryButton: View {
    let title: String
    /// Decorative: VoiceOver reads only the title. Fitted to `iconHeight`, whatever size its asset is.
    let icon: Image?
    let isLoading: Bool
    let isEnabled: Bool
    let action: () -> Void

    /// Every icon is this tall, keeping its proportions: the design's phone icon's own height, so icons exported at
    /// other sizes (the email envelope is 24×22) still match it.
    static let iconHeight: CGFloat = 15

    @Environment(\.auth0Theme) private var theme

    init(_ title: String, icon: Image? = nil, isLoading: Bool = false, isEnabled: Bool = true,
         action: @escaping () -> Void) {
        self.title = title
        self.icon = icon
        self.isLoading = isLoading
        self.isEnabled = isEnabled
        self.action = action
    }

    var body: some View {
        let shape = RoundedRectangle(cornerRadius: theme.radius.inputField, style: .continuous)
        Button {
            if !isLoading { action() }
        } label: {
            HStack(spacing: theme.spacing.xs) {
                if let icon {
                    icon
                        .resizable()
                        .scaledToFit()
                        .frame(height: Self.iconHeight)
                        .accessibilityHidden(true)
                }
                Text(title)
                    .auth0TextStyle(theme.typography.label)
            }
            .opacity(isLoading ? 0 : 1)
            .overlay {
                if isLoading { Auth0Loader(tintColor: theme.colors.text.bold) }
            }
            .foregroundStyle(theme.colors.text.bold)
            // Grows with Dynamic Type instead of clipping; 44pt at the default size.
            .padding(.vertical, theme.spacing.sm)
            .frame(maxWidth: .infinity, minHeight: 44)
            .background(theme.colors.background.layerTop, in: shape)
            .overlay(shape.strokeBorder(theme.colors.border.regular, lineWidth: 1))
            .contentShape(shape)
        }
        .buttonStyle(.plain)
        .accessibilityLabel(title)
        .accessibilityValue(isLoading ? "Loading" : "")
        // The busy button isn't disabled (its action ignores taps while loading), so the spinner isn't dimmed with it.
        .disabled(!isEnabled && !isLoading)
        .opacity(isEnabled || isLoading ? 1 : 0.5)
    }
}

#Preview {
    VStack(spacing: 12) {
        LoginSecondaryButton("Continue with Phone", icon: LoginChannel.phone.continueIcon) {}
        LoginSecondaryButton("Continue with Email", icon: LoginChannel.email.continueIcon) {}
        LoginSecondaryButton("Continue with Phone", icon: LoginChannel.phone.continueIcon, isEnabled: false) {}
        LoginSecondaryButton("Email me a code", icon: LoginChannel.email.continueIcon, isLoading: true) {}
    }
    .padding()
}
