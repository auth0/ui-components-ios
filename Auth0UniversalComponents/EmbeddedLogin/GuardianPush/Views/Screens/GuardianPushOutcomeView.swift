import SwiftUI

/// A terminal or retryable outcome: title, message and one action, with no icon.
public struct GuardianPushOutcomeView: View {
    let failure: GuardianPushFailure
    /// Retryable failures only (`failure.isRetryable`).
    let onRetry: (() -> Void)?
    /// Starts a new sign-in. `nil` hides the button.
    let onSignInAgain: (() -> Void)?

    public init(failure: GuardianPushFailure, onRetry: (() -> Void)? = nil, onSignInAgain: (() -> Void)? = nil) {
        self.failure = failure
        self.onRetry = onRetry
        self.onSignInAgain = onSignInAgain
    }

    public var body: some View {
        let content = GuardianPushOutcomeContent(failure)
        GuardianPushStatusLayout(title: content.title, message: content.message) {
            if failure.isRetryable, let onRetry {
                LoginPrimaryButton("Try again", action: onRetry)
            } else if let onSignInAgain {
                LoginPrimaryButton("Sign in again", action: onSignInAgain)
            }
        }
        .accessibilityElement(children: .contain)
    }
}
