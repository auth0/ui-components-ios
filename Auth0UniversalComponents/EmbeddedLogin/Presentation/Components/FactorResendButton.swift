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
            CountdownResendButton(remaining: cooldown.remaining(at: context.date), isBusy: isBusy, title: title,
                                  cooldownTitle: cooldownTitle) {
                onResend()
                cooldown.restart()
            }
        }
    }
}
