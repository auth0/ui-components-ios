import SwiftUI

/// A symbol shown above a status title: an SF Symbol and the colour to draw it in.
struct StatusIcon {
    let systemName: String
    let color: Color
}

/// Centered title and message with an optional icon and action, for terminal and transient outcomes.
/// Shared by the login's outcome screens and the factor screens.
struct StatusLayout<Action: View>: View {
    let title: String
    var message: String?
    var icon: StatusIcon?
    @ViewBuilder let action: () -> Action

    @Environment(\.auth0Theme) private var theme

    var body: some View {
        VStack(spacing: 0) {
            if let icon {
                Image(systemName: icon.systemName)
                    .font(.system(size: theme.sizes.statusIcon))
                    .foregroundStyle(icon.color)
                    .padding(.bottom, theme.spacing.md)
                    .accessibilityHidden(true)
            }
            Text(title)
                .auth0TextStyle(FactorScreenStyle.title)
                .foregroundStyle(theme.colors.text.bold)
                .accessibilityAddTraits(.isHeader)
            if let message {
                Text(message)
                    .auth0TextStyle(theme.typography.helper)
                    .foregroundStyle(theme.colors.text.regular)
                    .padding(.top, FactorScreenStyle.outcomeMessageTop)
            }
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

extension StatusLayout where Action == EmptyView {
    /// An outcome with nothing to do next.
    init(title: String, message: String? = nil, icon: StatusIcon? = nil) {
        self.init(title: title, message: message, icon: icon) { EmptyView() }
    }
}
