import SwiftUI

/// Filled resend button with a cooldown that starts when it appears and after each resend.
struct FactorResendButton: View {
    let isBusy: Bool
    let onResend: () -> Void
    let title: String
    let cooldownTitle: (Int) -> String

    /// Starts with the button: a new button (e.g. after a resend) waits again.
    @State private var cooldown: ResendCooldown

    init(cooldown: Int = 60, isBusy: Bool = false, title: String,
         cooldownTitle: @escaping (Int) -> String, onResend: @escaping () -> Void) {
        self.isBusy = isBusy
        self.onResend = onResend
        self.title = title
        self.cooldownTitle = cooldownTitle
        _cooldown = State(initialValue: ResendCooldown(seconds: cooldown))
    }

    var body: some View {
        TimelineView(.periodic(from: cooldown.startedAt, by: 1)) { context in
            let remaining = cooldown.remaining(at: context.date)
            Button(remaining > 0 ? cooldownTitle(remaining) : title) {
                onResend()
                cooldown.restart()
            }
            .buttonStyle(FactorFilledButtonStyle())
            .disabled(remaining > 0 || isBusy)
            .accessibilityLabel(remaining > 0 ? "\(title), available in \(remaining) seconds" : title)
        }
    }
}

/// `LoginPrimaryButton`'s look, except that disabled fades only the fill: the label stays `text.onPrimary`.
private struct FactorFilledButtonStyle: ButtonStyle {
    @Environment(\.auth0Theme) private var theme
    @Environment(\.isEnabled) private var isEnabled

    func makeBody(configuration: Configuration) -> some View {
        let shape = RoundedRectangle(cornerRadius: theme.radius.inputField, style: .continuous)
        return configuration.label
            .auth0TextStyle(theme.typography.label)
            .foregroundStyle(theme.colors.text.onPrimary)
            .frame(maxWidth: .infinity)
            .frame(height: 44)
            .background {
                shape.fill(theme.colors.background.primary)
                    .overlay(shape.fill(LinearGradient(colors: [.white.opacity(0.16), .white.opacity(0.04)],
                                                       startPoint: .top, endPoint: .bottom)))
                    .overlay(shape.strokeBorder(theme.colors.background.primary, lineWidth: 1))
                    // The design's greyed-out fill.
                    .opacity(isEnabled ? 1 : 0.45)
            }
            .shadow(color: .black.opacity(isEnabled ? 0.12 : 0), radius: 4, x: 0, y: 2)
            .contentShape(shape)
    }
}
