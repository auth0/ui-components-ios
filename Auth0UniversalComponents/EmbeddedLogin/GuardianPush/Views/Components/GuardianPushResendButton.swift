import SwiftUI
import Combine

/// Filled "Resend Code" button with a cooldown that starts when it appears and after each resend.
struct GuardianPushResendButton: View {
    let cooldown: Int
    let isBusy: Bool
    let onResend: () -> Void

    /// Starts at `cooldown`: a new button (e.g. after a resend) waits again.
    @State private var remaining: Int

    private let ticker = Timer.publish(every: 1, on: .main, in: .common).autoconnect()

    init(cooldown: Int = 60, isBusy: Bool = false, onResend: @escaping () -> Void) {
        self.cooldown = cooldown
        self.isBusy = isBusy
        self.onResend = onResend
        _remaining = State(initialValue: cooldown)
    }

    var body: some View {
        Button(remaining > 0 ? "Resend in \(remaining) sec…" : "Resend Code") {
            onResend()
            remaining = cooldown
        }
        .buttonStyle(GuardianPushFilledButtonStyle())
        .disabled(remaining > 0 || isBusy)
        .onReceive(ticker) { _ in if remaining > 0 { remaining -= 1 } }
    }
}

/// `LoginPrimaryButton`'s look, except that disabled fades only the fill: the label stays `text.onPrimary`.
private struct GuardianPushFilledButtonStyle: ButtonStyle {
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
