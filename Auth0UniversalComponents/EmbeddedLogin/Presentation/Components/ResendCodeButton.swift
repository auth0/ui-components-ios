import SwiftUI

/// "Resend Code" as plain text under Verify, reading "Resend in N sec…" while `remaining` is above 0. It owns no
/// countdown: the caller passes what's left, whether that's the sign-in's own timer (`LoginResendButton`) or the MFA
/// flow's, so every code screen looks and behaves the same.
struct ResendCodeButton: View {
    /// Seconds until resend is allowed; 0 when it can be used now.
    let remaining: Int
    /// Turns the row off while a code is being checked or sent.
    let isBusy: Bool
    let title: String
    let cooldownTitle: (Int) -> String
    let onResend: () -> Void

    @Environment(\.auth0Theme) private var theme

    init(remaining: Int, isBusy: Bool = false, title: String = "Resend Code",
         cooldownTitle: @escaping (Int) -> String = { "Resend in \($0) sec…" }, onResend: @escaping () -> Void) {
        self.remaining = remaining
        self.isBusy = isBusy
        self.title = title
        self.cooldownTitle = cooldownTitle
        self.onResend = onResend
    }

    var body: some View {
        Button(remaining > 0 ? cooldownTitle(remaining) : title, action: onResend)
            .buttonStyle(.plain)
            .auth0TextStyle(theme.typography.body)
            .foregroundStyle(theme.colors.text.regular.opacity(remaining > 0 || isBusy ? 0.7 : 1))
            .frame(maxWidth: .infinity)
            .disabled(remaining > 0 || isBusy)
            .accessibilityLabel(remaining > 0 ? "\(title), available in \(remaining) seconds" : title)
    }
}
