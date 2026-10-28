import Foundation

/// What the coordinator asks the renderer to show.
enum LoginStep: Equatable {
    case loading
    case collectOTPIdentifier
    /// `identifier` is the email the code was sent to.
    case collectOTPCode(identifier: String)
    /// Second factor: Guardian push, driven by `LoginFlowCoordinator.pushController`.
    case guardianPush
    /// A second factor is required, but none this flow can run is on offer. Terminal: only a new sign-in follows.
    case secondFactorUnavailable
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
    /// Starts a new sign-in, e.g. after the push was denied.
    case restart
}
