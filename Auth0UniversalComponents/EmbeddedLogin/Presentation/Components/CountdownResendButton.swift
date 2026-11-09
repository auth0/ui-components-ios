import SwiftUI

/// The resend button of every code screen. It owns no countdown: the caller passes what's left, whether that's the
/// flow's own (a factor's model) or a timer wrapper's (`LoginResendButton`). The button words it, turns itself off
/// while it counts down or the screen is busy, and labels it for VoiceOver. Only the look differs between screens.
struct CountdownResendButton: View {
    /// How the button is drawn.
    enum Look {
        /// A filled button, as under the push approval.
        case filled
        /// Plain text under Verify, as on the code screens.
        case text
    }

    /// Seconds until resend is allowed; 0 when it can be used now.
    let remaining: Int
    /// Turns the button off while a code is being checked or sent.
    let isBusy: Bool
    let title: String
    let cooldownTitle: (Int) -> String
    let look: Look
    let onResend: () -> Void

    @Environment(\.auth0Theme) private var theme

    init(remaining: Int, isBusy: Bool = false, title: String = "Resend Code",
         cooldownTitle: @escaping (Int) -> String = { "Resend in \($0) sec…" }, look: Look = .filled,
         onResend: @escaping () -> Void) {
        self.remaining = remaining
        self.isBusy = isBusy
        self.title = title
        self.cooldownTitle = cooldownTitle
        self.look = look
        self.onResend = onResend
    }

    var body: some View {
        switch look {
        case .filled:
            button
                .buttonStyle(FactorFilledButtonStyle())
        case .text:
            button
                .buttonStyle(.plain)
                .auth0TextStyle(theme.typography.body)
                .foregroundStyle(theme.colors.text.regular.opacity(isOff ? 0.7 : 1))
                .frame(maxWidth: .infinity)
        }
    }

    private var isOff: Bool { remaining > 0 || isBusy }

    private var button: some View {
        Button(remaining > 0 ? cooldownTitle(remaining) : title, action: onResend)
            .disabled(isOff)
            .accessibilityLabel(remaining > 0 ? "\(title), available in \(remaining) seconds" : title)
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

#Preview("Filled") {
    VStack(spacing: 16) {
        CountdownResendButton(remaining: 0) {}
        CountdownResendButton(remaining: 42) {}
    }
    .padding()
}

#Preview("Text") {
    VStack(spacing: 16) {
        CountdownResendButton(remaining: 0, look: .text) {}
        CountdownResendButton(remaining: 42, look: .text) {}
        CountdownResendButton(remaining: 0, isBusy: true, look: .text) {}
    }
    .padding()
}
