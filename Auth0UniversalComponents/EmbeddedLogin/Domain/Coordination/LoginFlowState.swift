import Foundation

/// What the coordinator asks the renderer to show.
enum LoginStep: Equatable {
    case loading
    /// Asks for what a way to sign in needs first: an email, a phone number or a username. The tenant's first method
    /// is the starting screen, listing the others; the others open on their own screen from there.
    case collectOTPIdentifier(LoginChannel)
    /// `identifier` is what the user typed. `sentTo` is where the server says the code went, masked
    /// (`(4**)***-*900`), when it says; otherwise the screen shows `identifier`. `canUsePassword` is whether the server
    /// also offers a password for them, which the screen then offers instead.
    case collectOTPCode(identifier: LoginIdentifier, sentTo: String? = nil, canUsePassword: Bool = false)
    /// The server asks for the password of what the user typed. `canSendCode` is whether it also offers a code, which
    /// the screen then offers instead.
    case collectPassword(identifier: LoginIdentifier, canSendCode: Bool = false)
    /// More than the first factor is required, and an additional step is running it
    /// (`LoginFlowCoordinator.additionalStep`).
    case additionalStep
    /// More is required, but nothing this flow can run is on offer, and the app wasn't told. Terminal: only a new
    /// sign-in follows.
    case additionalStepUnavailable
    case authenticated
    case failed(message: String)
    case noMethodsAvailable

    /// Whether the user types or taps here, as opposed to waiting or being told something.
    var isInputScreen: Bool {
        switch self {
        case .collectOTPIdentifier, .collectOTPCode, .collectPassword: return true
        default: return false
        }
    }
}

/// User input the renderer sends back to the coordinator.
enum LoginEvent: Equatable {
    case start
    case submitIdentifier(LoginIdentifier)
    /// "Continue with Phone" (or Email, or Password): opens that method's own screen.
    case chooseChannel(LoginChannel)
    case submitOTP(code: String)
    case submitPassword(String)
    /// "Email me a code", on the password screen of an email or number that was also offered a code.
    case sendCodeInstead
    /// "Continue with a password", on the code screen of an email or number that was also offered a password.
    case usePasswordInstead
    case retry
    /// Starts a new sign-in, e.g. after the additional step failed.
    case restart
}
