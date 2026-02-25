import SwiftUI

/// Renders a single toast notification message.
///
/// Colours and layout metrics are resolved from the active ``Auth0Theme``,
/// so the toast automatically matches any custom theme injected with
/// ``SwiftUI/View/auth0Theme(_:)``.
struct ToastView: View {

    @Environment(\.auth0Theme) private var theme

    /// The semantic intent that determines colours.
    var style: ToastStyle
    /// The message text to display.
    var message: String
    /// Callback invoked when the user dismisses the toast.
    var onCancelTapped: (() -> Void)

    var body: some View {
        Text(message)
            .auth0TextStyle(theme.typography.helper)
            .foregroundColor(style.messageColor(from: theme))
            .padding()
            .background(style.toastBackgroundColor(from: theme))
            .cornerRadius(theme.radius.small)
            .padding(.horizontal, theme.spacing.base)
    }
}
