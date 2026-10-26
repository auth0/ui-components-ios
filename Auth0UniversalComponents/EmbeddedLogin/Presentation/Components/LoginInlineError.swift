import SwiftUI

/// Red helper text beneath a field.
public struct LoginInlineError: View {
    let message: String
    @Environment(\.auth0Theme) private var theme

    public init(_ message: String) { self.message = message }

    public var body: some View {
        Text(message)
            .auth0TextStyle(theme.typography.bodySmall)
            .foregroundStyle(theme.colors.loginError)
            .frame(maxWidth: .infinity, alignment: .leading)
            .fixedSize(horizontal: false, vertical: true)
    }
}
