import SwiftUI

/// "Resend Code" with a cooldown that starts when it appears and after each resend. The button is
/// `CountdownResendButton`'s, as plain text; this only owns the timer.
public struct LoginResendButton: View {
    /// Disables the row while a verify is in flight.
    let isBusy: Bool
    /// Skips what's left of the countdown, e.g. when the code expired and only a new one helps.
    let isAvailableNow: Bool
    let onResend: () -> Void

    /// Starts with the button, so typing in the code field (which redraws it) can't hold the countdown back.
    @State private var cooldown: ResendCooldown

    public init(cooldown: Int = 60, isBusy: Bool = false, isAvailableNow: Bool = false,
                onResend: @escaping () -> Void) {
        self.isBusy = isBusy
        self.isAvailableNow = isAvailableNow
        self.onResend = onResend
        _cooldown = State(initialValue: ResendCooldown(seconds: cooldown))
    }

    public var body: some View {
        TimelineView(.periodic(from: cooldown.startedAt, by: 1)) { context in
            CountdownResendButton(remaining: isAvailableNow ? 0 : cooldown.remaining(at: context.date),
                                  isBusy: isBusy, look: .text) {
                onResend()
                cooldown.restart()
            }
        }
    }
}
