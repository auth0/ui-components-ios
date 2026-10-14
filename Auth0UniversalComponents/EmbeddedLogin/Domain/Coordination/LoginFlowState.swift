import Foundation

/// What the coordinator asks the renderer to show.
enum LoginStep: Equatable {
    case loading
    case collectOTPIdentifier
    /// `identifier` is the email the code was sent to.
    case collectOTPCode(identifier: String)
    case authenticated
    case failed(message: String)
    case noMethodsAvailable
}

/// User input the renderer sends back to the coordinator.
enum LoginEvent: Equatable {
    case start
    case submitIdentifier(String)
    case submitOTP(code: String)
    case retry
}
