import SwiftUI

/// A loading indicator for Auth0 UI Components with two rendering modes.
///
/// **Standalone (default)** — `Auth0Loader()` renders a floating card centred
/// in its parent container. The card uses the theme's primary colour as its
/// background, `onPrimary` for the spinner and label, rounded corners, and a
/// subtle drop shadow to lift it off the page background.
///
/// **Inline** — `Auth0Loader(tintColor:)` renders a compact spinner only,
/// intended for use inside button labels where the button background already
/// provides context.
///
/// ```swift
/// // Standalone page-level loader
/// Auth0Loader()
///
/// // Inline inside a primary-colour button label
/// Auth0Loader(tintColor: theme.colors.text.onPrimary)
/// ```
struct Auth0Loader: View {

    @Environment(\.auth0Theme) private var theme

    /// When non-`nil` the view renders as a compact inline spinner using this
    /// colour. When `nil` (the default) a full standalone card is rendered.
    var tintColor: Color?

    init(tintColor: Color? = nil) {
        self.tintColor = tintColor
    }

    var body: some View {
        if let tintColor {
            // Compact inline variant — sits inside button labels.
            ProgressView()
                .progressViewStyle(CircularProgressViewStyle())
                .tint(tintColor)
                .scaleEffect(1.5)
                .frame(width: 50, height: 50)
        } else {
            // Standalone card variant — scrim fills the full container and
            // floats a centred dialog card on top.
            Color.black.opacity(0.25)
                .ignoresSafeArea()
                .overlay {
                    VStack(spacing: theme.spacing.md) {
                        ProgressView()
                            .progressViewStyle(CircularProgressViewStyle())
                            .tint(theme.colors.background.primary)
                            .scaleEffect(1.4)

                        Text("Loading…")
                            .auth0TextStyle(theme.typography.label)
                            .foregroundStyle(theme.colors.text.bold)
                    }
                    .padding(.horizontal, 36)
                    .padding(.vertical, 28)
                    .background(theme.colors.background.layerTop)
                    .clipShape(RoundedRectangle(cornerRadius: 20))
                    .shadow(color: Color.black.opacity(0.18), radius: 24, x: 0, y: 8)
                }
        }
    }
}
