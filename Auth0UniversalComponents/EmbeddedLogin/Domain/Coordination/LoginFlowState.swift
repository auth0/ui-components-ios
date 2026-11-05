import Foundation

/// What the coordinator asks the renderer to show.
enum LoginStep: Equatable {
    case loading
    /// Asks for an email or a phone number. The tenant's first method is the starting screen, listing the others; the
    /// others open on their own screen from there.
    case collectOTPIdentifier(LoginChannel)
    /// `identifier` is what the user typed. `sentTo` is where the server says the code went, masked
    /// (`(4**)***-*900`), when it says; otherwise the screen shows `identifier`.
    case collectOTPCode(identifier: LoginIdentifier, sentTo: String? = nil)
    /// More than the first factor is required, and an additional step is running it
    /// (`LoginFlowCoordinator.additionalStep`).
    case additionalStep
    /// More is required, but nothing this flow can run is on offer, and the app wasn't told. Terminal: only a new
    /// sign-in follows.
    case additionalStepUnavailable
    case authenticated
    case failed(message: String)
    case noMethodsAvailable
}

/// User input the renderer sends back to the coordinator.
enum LoginEvent: Equatable {
    case start
    case submitIdentifier(LoginIdentifier)
    /// "Continue with Phone" (or Email): opens that method's own screen.
    case chooseChannel(LoginChannel)
    case submitOTP(code: String)
    case retry
    /// Starts a new sign-in, e.g. after the additional step failed.
    case restart
}
