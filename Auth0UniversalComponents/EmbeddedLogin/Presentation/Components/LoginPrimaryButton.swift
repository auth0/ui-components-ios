import SwiftUI

/// Full-width primary button with an in-place loader.
public struct LoginPrimaryButton: View {
    let title: String
    let isLoading: Bool
    let isEnabled: Bool
    let action: () -> Void

    @Environment(\.auth0Theme) private var theme

    public init(_ title: String, isLoading: Bool = false, isEnabled: Bool = true, action: @escaping () -> Void) {
        self.title = title
        self.isLoading = isLoading
        self.isEnabled = isEnabled
        self.action = action
    }

    public var body: some View {
        let shape = RoundedRectangle(cornerRadius: theme.radius.inputField, style: .continuous)
        Button(action: { if !isLoading { action() } }) {
            ZStack {
                if isLoading {
                    Auth0Loader(tintColor: theme.colors.text.onPrimary)
                } else {
                    Text(title)
                        .auth0TextStyle(theme.typography.label)
                        .foregroundStyle(theme.colors.text.onPrimary)
                }
            }
            .frame(maxWidth: .infinity)
            .frame(height: 44)
            .background(fill, in: shape)
            .overlay(shape.fill(LinearGradient(colors: [.white.opacity(0.16), .white.opacity(0.04)],
                                               startPoint: .top, endPoint: .bottom)))
            .overlay(shape.strokeBorder(theme.colors.background.primary.opacity(isLoading ? 0 : 1), lineWidth: 1))
            .shadow(color: .black.opacity(isEnabled && !isLoading ? 0.12 : 0), radius: 4, x: 0, y: 2)
            .contentShape(shape)
        }
        .buttonStyle(.plain)
        .disabled(!isEnabled || isLoading)
        .opacity(isEnabled || isLoading ? 1 : 0.5)
    }

    private var fill: Color {
        isLoading ? theme.colors.background.primary.opacity(0.7) : theme.colors.background.primary
    }
}
