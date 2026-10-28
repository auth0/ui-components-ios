import SwiftUI

/// A tappable Guardian device: icon, name and chevron.
public struct GuardianPushDeviceRow: View {
    let device: GuardianPushDevice
    let action: () -> Void

    @Environment(\.auth0Theme) private var theme

    public init(device: GuardianPushDevice, action: @escaping () -> Void) {
        self.device = device
        self.action = action
    }

    public var body: some View {
        Button(action: action) {
            HStack(spacing: theme.spacing.md) {
                Image("totp", bundle: ResourceBundle.default)
                    .renderingMode(.template)
                    .resizable()
                    .scaledToFit()
                    .frame(width: GuardianPushStyle.rowIconSize, height: GuardianPushStyle.rowIconSize)
                    .foregroundStyle(theme.colors.background.primary)
                    .accessibilityHidden(true)
                Text(device.name)
                    .auth0TextStyle(theme.typography.label)
                    .foregroundStyle(theme.colors.text.bold)
                    .lineLimit(2)
                    .multilineTextAlignment(.leading)
                    .frame(maxWidth: .infinity, alignment: .leading)
                Image("chevron", bundle: ResourceBundle.default)
                    .renderingMode(.template)
                    .foregroundStyle(theme.colors.background.primary)
                    .frame(width: theme.sizes.iconSmall, height: theme.sizes.iconSmall)
                    .accessibilityHidden(true)
            }
            .padding(.leading, GuardianPushStyle.rowLeading)
            .padding(.trailing, theme.spacing.lg)
            .padding(.vertical, theme.spacing.sm)
            .frame(minHeight: theme.sizes.inputHeight + theme.spacing.xxs)
        }
        .buttonStyle(GuardianPushRowStyle())
        .accessibilityLabel(device.name)
        .accessibilityHint("Sends a sign-in request to this device")
    }
}

/// Resting rows sit on an off-white card; a pressed row lifts to white with a stronger border.
private struct GuardianPushRowStyle: ButtonStyle {
    @Environment(\.auth0Theme) private var theme

    func makeBody(configuration: Configuration) -> some View {
        let isPressed = configuration.isPressed
        let shape = RoundedRectangle(cornerRadius: theme.radius.medium)
        return configuration.label
            .background(isPressed ? theme.colors.background.layerTop : theme.colors.background.layerMedium, in: shape)
            .overlay(shape.strokeBorder(isPressed ? theme.colors.border.bold : theme.colors.border.regular,
                                        lineWidth: 1))
            .shadow(color: .black.opacity(isPressed ? 0.08 : 0), radius: 6, x: 0, y: 2)
            .contentShape(shape)
            .animation(.easeOut(duration: 0.12), value: isPressed)
    }
}
