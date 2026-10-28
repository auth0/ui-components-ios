import SwiftUI

/// Centered secondary text action, e.g. "Choose another device".
public struct GuardianPushTextButton: View {
    let title: String
    let isEnabled: Bool
    let action: () -> Void

    @Environment(\.auth0Theme) private var theme

    public init(_ title: String, isEnabled: Bool = true, action: @escaping () -> Void) {
        self.title = title
        self.isEnabled = isEnabled
        self.action = action
    }

    public var body: some View {
        Button(title, action: action)
            .buttonStyle(.plain)
            .auth0TextStyle(GuardianPushStyle.action)
            .foregroundStyle(theme.colors.text.bold.opacity(isEnabled ? 1 : 0.5))
            .frame(maxWidth: .infinity, minHeight: 44)
            .contentShape(Rectangle())
            .disabled(!isEnabled)
    }
}
