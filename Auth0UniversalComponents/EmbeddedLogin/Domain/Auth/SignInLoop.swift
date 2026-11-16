/// Who a sign-in is for and the connection it was opened on: what it takes to open it again.
struct SignInIdentity: Equatable {
    let identifier: LoginIdentifier
    let connection: String
}

/// Where the sign-in stands with the server, in one place. The SDK ends it on every failure except a continuation or a
/// network error, so this says whether there is anything left to continue.
enum SignInLoop: Equatable {
    /// Nothing to continue: the next identifier opens a sign-in.
    case closed
    /// A live sign-in with nobody identified on it yet: discovery just opened it, or a re-open for the identity stopped
    /// before the server had them.
    case opened(SignInIdentity?)
    /// The server has the identifier and has said everything it offers.
    case identified(SignInIdentity)
    /// Alive, but a wrong password narrowed the offer to the password alone, so a code needs a new sign-in.
    case passwordOnly(SignInIdentity)
    /// A code was sent on this sign-in, which is where it is checked.
    case codeSent(SignInIdentity)
    /// The server ended it. Only a new sign-in for the same person continues.
    case ended(SignInIdentity)

    /// Who the sign-in is for, once the server knows.
    var identity: SignInIdentity? {
        switch self {
        case let .opened(identity):
            return identity
        case let .identified(identity), let .passwordOnly(identity), let .codeSent(identity), let .ended(identity):
            return identity
        case .closed:
            return nil
        }
    }

    var isOpened: Bool {
        if case .opened = self { return true }
        return false
    }

    /// Whether the server has the person and is waiting for their password.
    var isReadyForPassword: Bool {
        switch self {
        case .identified, .passwordOnly: return true
        case .closed, .opened, .codeSent, .ended: return false
        }
    }
}
