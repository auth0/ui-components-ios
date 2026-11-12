import SwiftUI

/// A box and its label, which toggle together: tapping either flips `isOn`. Holds no rules: the host decides what
/// ticking it unlocks.
struct LoginCheckbox: View {
    let title: String
    @Binding var isOn: Bool

    @Environment(\.auth0Theme) private var theme

    var body: some View {
        Button { isOn.toggle() } label: {
            HStack(spacing: theme.spacing.sm) {
                box
                Text(title)
                    .auth0TextStyle(theme.typography.body)
                    .foregroundStyle(theme.colors.text.bold)
                    .multilineTextAlignment(.leading)
                Spacer(minLength: 0)
            }
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .accessibilityAddTraits(isOn ? .isSelected : [])
    }

    private var box: some View {
        let shape = RoundedRectangle(cornerRadius: theme.radius.small, style: .continuous)
        let edge = isOn ? theme.colors.background.primary : theme.colors.border.regular
        return shape
            .fill(isOn ? theme.colors.background.primary : theme.colors.background.layerTop)
            .overlay(shape.strokeBorder(edge, lineWidth: 1))
            .overlay {
                if isOn {
                    Image(systemName: "checkmark")
                        .font(.system(size: 12, weight: .bold))
                        .foregroundStyle(theme.colors.text.onPrimary)
                }
            }
            .frame(width: 20, height: 20)
    }
}

#Preview("Checkbox") {
    VStack(alignment: .leading, spacing: 16) {
        LoginCheckbox(title: "I have saved this recovery code", isOn: .constant(false))
        LoginCheckbox(title: "I have saved this recovery code", isOn: .constant(true))
    }
    .padding()
}
