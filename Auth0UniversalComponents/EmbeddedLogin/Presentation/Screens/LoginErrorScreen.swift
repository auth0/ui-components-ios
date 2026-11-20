import SwiftUI

/// Message with a "Try again" action. The title and the action's words can be replaced, for a flow that isn't a
/// sign-in.
public struct LoginErrorScreen: View {
    let message: String
    let title: String
    let retryTitle: String
    let onRetry: () -> Void

    public init(message: String = "", title: String = "Sign in couldn't be completed.",
                retryTitle: String = "Try again", onRetry: @escaping () -> Void) {
        self.message = message
        self.title = title
        self.retryTitle = retryTitle
        self.onRetry = onRetry
    }

    public var body: some View {
        StatusLayout(
            title: title,
            message: message.isEmpty
                ? "We are unable to process your request. Please try again in a few minutes."
                : message
        ) {
            LoginPrimaryButton(retryTitle, action: onRetry)
        }
    }
}

#Preview("Error") { LoginErrorScreen {} }
