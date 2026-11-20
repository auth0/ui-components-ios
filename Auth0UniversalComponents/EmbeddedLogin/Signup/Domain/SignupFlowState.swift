import Auth0

/// What the sign-up coordinator asks the screens to show.
enum SignupStep: Equatable {
    case loading
    /// Asks for one identifier. The first screen, and where Edit and Back from the code screen return to.
    case collectIdentifier(SignupIdentifierKind)
    /// A code went out to `identifier`.
    case collectCode(SignupCodeStep)
    /// Every required identifier is verified. Continue creates the account.
    case confirm
    case authenticated
    /// The connection offers no sign-up this flow can finish.
    case unavailable
    /// `canRetry` is false once the sign-up has ended: only "Start over" follows.
    case failed(message: String, canRetry: Bool)
}

struct SignupCodeStep: Equatable {
    let identifier: SignupIdentifierValue
    let challenge: SignupChallenge
}

/// What the screens send back.
enum SignupEvent: Equatable {
    case start
    /// "Start over", after the sign-up ended.
    case restart
    case submitIdentifier(SignupIdentifierValue)
    case submitCode(String)
    case resend
    /// Continue on the verified screen.
    case confirm
    case retry
}
