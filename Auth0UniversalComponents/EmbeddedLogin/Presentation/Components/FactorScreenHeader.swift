import SwiftUI

/// Title with a wrapping subtitle, as on the factor screens.
struct FactorScreenHeader: View {
    let title: String
    let subtitle: String?
    let subtitleStyle: Auth0TextStyle?
    let spacing: CGFloat?

    @Environment(\.auth0Theme) private var theme

    /// `nil` style and spacing use `typography.bodySmall` and `spacing.sm`.
    init(title: String, subtitle: String? = nil, subtitleStyle: Auth0TextStyle? = nil, spacing: CGFloat? = nil) {
        self.title = title
        self.subtitle = subtitle
        self.subtitleStyle = subtitleStyle
        self.spacing = spacing
    }

    var body: some View {
        VStack(alignment: .leading, spacing: spacing ?? theme.spacing.sm) {
            Text(title)
                .auth0TextStyle(FactorScreenStyle.title)
                .foregroundStyle(theme.colors.text.bold)
                .accessibilityAddTraits(.isHeader)
            if let subtitle {
                Text(subtitle)
                    .auth0TextStyle(subtitleStyle ?? theme.typography.bodySmall)
                    .foregroundStyle(theme.colors.text.regular)
            }
        }
        .fixedSize(horizontal: false, vertical: true)
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}
