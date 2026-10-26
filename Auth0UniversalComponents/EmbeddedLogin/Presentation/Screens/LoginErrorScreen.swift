import SwiftUI

/// Message with a "Try again" action, biased slightly above center.
public struct LoginErrorScreen: View {
    let message: String
    let onRetry: () -> Void

    public init(message: String = "", onRetry: @escaping () -> Void) {
        self.message = message
        self.onRetry = onRetry
    }

    public var body: some View {
        VStack(spacing: 14) {
            Spacer()
            StatusText(title: "Sign in couldn't be completed.",
                       message: message.isEmpty ? "We are unable to process your request. Please try again in a few minutes." : message)
            PrimaryPillButton(title: "Try again", action: onRetry)
                .padding(.top, 18)
            Spacer()
            Spacer()
        }
        .padding(.horizontal, 28)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}

#Preview("Error") { LoginErrorScreen {} }
