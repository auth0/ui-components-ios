import SwiftUI

/// Label above a field.
public struct LoginFieldLabel: View {
    let text: String
    @Environment(\.auth0Theme) private var theme

    public init(_ text: String) { self.text = text }

    public var body: some View {
        Text(text)
            .auth0TextStyle(theme.typography.label)
            .foregroundStyle(theme.colors.text.bold)
            .padding(.bottom, theme.spacing.md)
    }
}
