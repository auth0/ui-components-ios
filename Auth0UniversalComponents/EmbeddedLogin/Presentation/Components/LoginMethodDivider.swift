import SwiftUI

/// A hairline with a word in the middle ("OR"), between the primary way to continue and the others.
struct LoginMethodDivider: View {
    let text: String

    @Environment(\.auth0Theme) private var theme

    init(_ text: String = "OR") {
        self.text = text
    }

    var body: some View {
        HStack(spacing: theme.spacing.md) {
            line
            Text(text)
                .auth0TextStyle(theme.typography.bodySmall)
                .foregroundStyle(theme.colors.text.regular)
                .fixedSize()
            line
        }
        .frame(maxWidth: .infinity)
        .accessibilityHidden(true)
    }

    private var line: some View {
        Rectangle()
            .fill(theme.colors.border.regular)
            .frame(maxWidth: .infinity)
            .frame(height: 1)
            .accessibilityHidden(true)
    }
}

#Preview {
    LoginMethodDivider()
        .padding()
}
