import SwiftUI

/// One of a few choices, side by side: an outlined button like `LoginSecondaryButton`, with a heavier outline and a
/// soft ring around the one that is chosen.
struct LoginChoiceButton: View {
    let title: String
    let isSelected: Bool
    let isEnabled: Bool
    let action: () -> Void

    @Environment(\.auth0Theme) private var theme

    init(_ title: String, isSelected: Bool, isEnabled: Bool = true, action: @escaping () -> Void) {
        self.title = title
        self.isSelected = isSelected
        self.isEnabled = isEnabled
        self.action = action
    }

    var body: some View {
        let shape = RoundedRectangle(cornerRadius: theme.radius.inputField, style: .continuous)
        Button(action: action) {
            Text(title)
                .auth0TextStyle(theme.typography.label)
                .foregroundStyle(theme.colors.text.bold)
                .padding(.vertical, theme.spacing.sm)
                .frame(maxWidth: .infinity, minHeight: theme.sizes.tapTarget)
                .background(theme.colors.background.layerTop, in: shape)
                .overlay(shape.strokeBorder(isSelected ? theme.colors.text.bold : theme.colors.border.regular,
                                           lineWidth: isSelected ? theme.sizes.borderWidthStrong
                                                                 : theme.sizes.borderWidth))
                .softRing(isSelected, cornerRadius: theme.radius.inputField,
                           color: theme.colors.border.subtle, width: theme.sizes.focusRingWidth,
                           overhang: theme.sizes.focusRingWidth)
                .contentShape(shape)
        }
        .buttonStyle(.plain)
        .disabled(!isEnabled)
        .opacity(isEnabled ? 1 : 0.5)
        .accessibilityAddTraits(isSelected ? .isSelected : [])
    }
}

#Preview {
    HStack(spacing: 16) {
        LoginChoiceButton("Text message", isSelected: true) {}
        LoginChoiceButton("Voice call", isSelected: false) {}
    }
    .padding()
}
