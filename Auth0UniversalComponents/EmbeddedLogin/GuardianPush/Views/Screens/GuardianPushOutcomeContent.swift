import SwiftUI

/// Copy for each outcome.
struct GuardianPushOutcomeContent: Equatable {
    let title: String
    let message: String

    init(_ failure: GuardianPushFailure) {
        switch failure {
        case .unavailable:
            self.init(title: "Push notification isn't available.",
                      message: "This account doesn't have a Guardian device that can approve this sign-in.")
        case .denied:
            self.init(title: "Sign-in request denied.",
                      message: "The request was denied in Guardian. "
                          + "If you didn't try to sign in, change your password.")
        case .expired:
            self.init(title: "Request expired.",
                      message: "The request wasn't approved in time. Sign in again to send a new one.")
        case .sessionEnded:
            self.init(title: "Sign-in session ended.",
                      message: "Your sign-in session ended. Please sign in again.")
        case .network:
            self.init(title: "No connection.",
                      message: "Check your connection and try again.")
        case let .other(message):
            self.init(title: "Sign in couldn't be completed.",
                      message: message ?? "We are unable to process your request. Please try again in a few minutes.")
        }
    }

    private init(title: String, message: String) {
        self.title = title
        self.message = message
    }
}
