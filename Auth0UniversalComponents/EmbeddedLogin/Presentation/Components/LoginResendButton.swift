import Combine
import SwiftUI

/// "Resend Code" with a cooldown that starts on appear and after each resend.
public struct LoginResendButton: View {
    let cooldown: Int
    /// Disables the row while a verify is in flight.
    let isBusy: Bool
    let onResend: () -> Void

    @Environment(\.auth0Theme) private var theme
    @State private var remaining = 0

    private let ticker = Timer.publish(every: 1, on: .main, in: .common).autoconnect()

    public init(cooldown: Int = 60, isBusy: Bool = false, onResend: @escaping () -> Void) {
        self.cooldown = cooldown
        self.isBusy = isBusy
        self.onResend = onResend
    }

    private var isCoolingDown: Bool { remaining > 0 }

    public var body: some View {
        Button(isCoolingDown ? "Resend in \(remaining) sec…" : "Resend Code") {
            onResend()
            remaining = cooldown
        }
        .buttonStyle(.plain)
        .auth0TextStyle(theme.typography.body)
        .foregroundStyle(theme.colors.text.regular.opacity(isCoolingDown || isBusy ? 0.7 : 1))
        .frame(maxWidth: .infinity)
        .disabled(isCoolingDown || isBusy)
        .onAppear { if remaining == 0 { remaining = cooldown } }
        .onReceive(ticker) { _ in if remaining > 0 { remaining -= 1 } }
        .accessibilityLabel(isCoolingDown ? "Resend code, available in \(remaining) seconds" : "Resend code")
    }
}
