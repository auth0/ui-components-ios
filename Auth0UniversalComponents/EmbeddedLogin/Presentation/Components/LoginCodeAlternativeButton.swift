import SwiftUI

/// The password screen's way to a code ("Email me a code"): a secondary button that counts down while a code was just
/// sent, as Resend does, so asking for one again can't be done on every tap.
struct LoginCodeAlternativeButton: View {
    let title: String
    let icon: Image?
    /// When another code may be asked for; `nil`, or a time that has passed, means now.
    let availableAt: Date?
    let isLoading: Bool
    let isEnabled: Bool
    let action: () -> Void

    var body: some View {
        if let availableAt {
            TimelineView(.periodic(from: .now, by: 1)) { context in
                button(remaining: ResendCooldown.remaining(until: availableAt, at: context.date))
            }
        } else {
            button(remaining: 0)
        }
    }

    private func button(remaining: Int) -> some View {
        LoginSecondaryButton(Self.title(title, remaining: remaining), icon: icon, isLoading: isLoading,
                             isEnabled: isEnabled && remaining == 0, action: action)
    }

    /// "Email me a code", or "Email me a code in 42s" while it waits.
    static func title(_ title: String, remaining: Int) -> String {
        remaining > 0 ? "\(title) in \(remaining)s" : title
    }
}

#Preview {
    VStack(spacing: 12) {
        LoginCodeAlternativeButton(title: "Email me a code", icon: LoginChannel.email.continueIcon, availableAt: nil,
                                   isLoading: false, isEnabled: true) {}
        LoginCodeAlternativeButton(title: "Email me a code", icon: LoginChannel.email.continueIcon,
                                   availableAt: .now.addingTimeInterval(42), isLoading: false, isEnabled: true) {}
    }
    .padding()
}
