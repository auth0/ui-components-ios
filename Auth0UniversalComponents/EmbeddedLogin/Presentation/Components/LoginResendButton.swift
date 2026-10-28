import SwiftUI

/// "Resend Code" with a cooldown that starts when it appears and after each resend.
public struct LoginResendButton: View {
    /// Disables the row while a verify is in flight.
    let isBusy: Bool
    let onResend: () -> Void

    @Environment(\.auth0Theme) private var theme
    /// Starts with the button, so typing in the code field (which redraws it) can't hold the countdown back.
    @State private var cooldown: ResendCooldown

    public init(cooldown: Int = 60, isBusy: Bool = false, onResend: @escaping () -> Void) {
        self.isBusy = isBusy
        self.onResend = onResend
        _cooldown = State(initialValue: ResendCooldown(seconds: cooldown))
    }

    public var body: some View {
        TimelineView(.periodic(from: cooldown.startedAt, by: 1)) { context in
            let remaining = cooldown.remaining(at: context.date)
            Button(remaining > 0 ? "Resend in \(remaining) sec…" : "Resend Code") {
                onResend()
                cooldown.restart()
            }
            .buttonStyle(.plain)
            .auth0TextStyle(theme.typography.body)
            .foregroundStyle(theme.colors.text.regular.opacity(remaining > 0 || isBusy ? 0.7 : 1))
            .frame(maxWidth: .infinity)
            .disabled(remaining > 0 || isBusy)
            .accessibilityLabel(remaining > 0 ? "Resend code, available in \(remaining) seconds" : "Resend code")
        }
    }
}
