import SwiftUI

// MARK: - Card Skeleton Container

/// A themed card-shaped container that lays out arbitrary skeleton content with the same
/// padding, border, and corner radius as the SDK's real cards. Use it to keep bespoke
/// skeletons visually consistent with `MyAccountAuthMethodView` / `AuthenticatorView`.
struct SkeletonCard<Content: View>: View {

    @Environment(\.auth0Theme) private var theme

    @ViewBuilder let content: () -> Content

    var body: some View {
        content()
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(theme.spacing.lg)
            .overlay {
                RoundedRectangle(cornerRadius: theme.radius.button)
                    .stroke(theme.colors.border.regular, lineWidth: 1)
            }
    }
}
