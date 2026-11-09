import SwiftUI

/// Rounded input container. `isInvalid` switches to the error treatment (pink fill, red text).
public struct LoginInputField<Content: View, Trailing: View>: View {
    let isInvalid: Bool
    let content: () -> Content
    let trailing: () -> Trailing

    @Environment(\.auth0Theme) private var theme

    public init(isInvalid: Bool = false,
                @ViewBuilder content: @escaping () -> Content,
                @ViewBuilder trailing: @escaping () -> Trailing = { EmptyView() }) {
        self.isInvalid = isInvalid
        self.content = content
        self.trailing = trailing
    }

    public var body: some View {
        let shape = RoundedRectangle(cornerRadius: theme.radius.inputField, style: .continuous)
        HStack(spacing: theme.spacing.sm) {
            content()
                .auth0TextStyle(theme.typography.label)
                .foregroundStyle(isInvalid ? theme.colors.loginError : theme.colors.text.bold)
                .tint(isInvalid ? theme.colors.loginError : theme.colors.background.primary)
            trailing()
        }
        .padding(.horizontal, theme.spacing.md)
        .frame(height: theme.sizes.size3xlDimen)
        .background(isInvalid ? theme.colors.background.errorSubtle : theme.colors.background.layerTop, in: shape)
        .overlay(shape.strokeBorder(isInvalid ? theme.colors.errorBorder : theme.colors.border.subtle, lineWidth: 1))
        .errorRing(isInvalid, cornerRadius: theme.radius.inputField, color: theme.colors.errorRing)
        .shadow(color: .black.opacity(isInvalid ? 0 : 0.05), radius: 6, x: 0, y: 2)
    }
}
