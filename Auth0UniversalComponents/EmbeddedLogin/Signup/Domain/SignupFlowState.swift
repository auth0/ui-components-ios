/// What the sign-up coordinator asks the screens to show.
enum SignupStep: Equatable {
    case loading
    /// Asks for one identifier. The first screen, and where Edit and Back from the code screen return to.
    case collectIdentifier(SignupIdentifierKind)
    /// The number takes more than one way to get a code: the user chooses before one is sent.
    case chooseDelivery(SignupDeliveryStep)
    /// A code went out to `identifier`.
    case collectCode(SignupCodeStep)
    case authenticated
    /// The connection offers no sign-up this flow can finish.
    case unavailable
    /// `canRetry` is false once the sign-up has ended: only "Start over" follows.
    case failed(message: String, canRetry: Bool)
}

/// An identifier the server accepted and will send a code to, once the user has chosen how.
struct SignupDeliveryStep: Equatable {
    let identifier: SignupIdentifierValue
    let challenge: SignupChallenge
}

struct SignupCodeStep: Equatable {
    let identifier: SignupIdentifierValue
    let challenge: SignupChallenge
    /// How the code on its way was sent.
    let delivery: CodeDelivery
    /// The code timed out: only a new one helps.
    var isExpired = false

    init(identifier: SignupIdentifierValue, challenge: SignupChallenge, delivery: CodeDelivery) {
        self.identifier = identifier
        self.challenge = challenge
        self.delivery = delivery
    }

    func expired() -> SignupCodeStep {
        var copy = self
        copy.isExpired = true
        return copy
    }
}

/// What the screens send back.
enum SignupEvent: Equatable {
    case start
    /// "Start over", after the sign-up ended.
    case restart
    case submitIdentifier(SignupIdentifierValue)
    case submitCode(String)
    /// A new code, the way the last one went.
    case resend
    /// Continue on the screen that asks how to get the code: send it that way.
    case chooseDelivery(CodeDelivery)
    case retry
}
