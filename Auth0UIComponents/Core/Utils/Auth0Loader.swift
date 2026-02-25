import SwiftUI

/// A circular loading indicator for Auth0 UI Components.
///
/// Displays a `ProgressView` scaled to a comfortable touch-area size.
/// By default the tint is read from the active ``Auth0Theme``; pass an
/// explicit `tintColor` to override it for a specific context (for example,
/// white text on a dark primary button).
///
/// ```swift
/// // Default — uses theme.colors.textSecondary
/// Auth0Loader()
///
/// // Explicit override — used inside primary-colour buttons
/// Auth0Loader(tintColor: theme.colors.onPrimary)
/// ```
struct Auth0Loader: View {

    @Environment(\.auth0Theme) private var theme

    /// Optional tint-colour override. When `nil` the active theme's
    /// ``Auth0ColorTokens/textSecondary`` is used automatically.
    var tintColor: Color?

    /// Initialises the loader with an optional tint override.
    ///
    /// - Parameter tintColor: Explicit tint colour. Pass `nil` (the default)
    ///   to inherit ``Auth0ColorTokens/textSecondary`` from the active theme.
    init(tintColor: Color? = nil) {
        self.tintColor = tintColor
    }

    var body: some View {
        ProgressView()
            .progressViewStyle(CircularProgressViewStyle())
            .tint(tintColor ?? theme.colors.textSecondary)
            .scaleEffect(1.5)
            .frame(width: 50, height: 50)
    }
}
