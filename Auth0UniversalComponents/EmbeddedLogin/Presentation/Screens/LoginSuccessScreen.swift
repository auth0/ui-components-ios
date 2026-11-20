import SwiftUI

/// Shown briefly before the host routes away.
public struct LoginSuccessScreen: View {
    @Environment(\.auth0Theme) private var theme

    public init() {}

    public var body: some View {
        StatusLayout(
            title: "You're signed in",
            icon: StatusIcon(systemName: "checkmark.seal.fill", color: theme.colors.foreground.success)
        )
    }
}

#Preview("Success") { LoginSuccessScreen() }
