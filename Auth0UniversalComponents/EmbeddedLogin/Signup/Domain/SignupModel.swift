import Auth0

// What a sign-up is made of, and how the server's menu (`next`) is read. This is the only file that looks inside a
// `NextAction` for sign-up, so a new kind of identifier changes it and the screens, and nothing in between.

/// What a new account can be identified by. A kind the server offers that isn't here is left out, so the flow never
/// shows a screen it can't finish. Adding one is a new case: the compiler then lists each place that needs it.
enum SignupIdentifierKind: CaseIterable, Hashable, Sendable {
    case email

    /// `nil` for a kind this flow has no screens for.
    init?(_ type: IdentifierType) {
        switch type {
        case .email: self = .email
        case .phone, .username: return nil
        }
    }

    /// The steps the server must be able to offer for this kind, so `authorize` never advertises one with no screen.
    var capabilities: [EmbeddedCapability] {
        switch self {
        case .email: return [.identifyEmail, .challengeEmail, .verifyOTP]
        }
    }

    var identifierType: IdentifierType {
        switch self {
        case .email: return .email
        }
    }

    /// The title of the screen shown once this kind is verified.
    var verifiedTitle: String {
        switch self {
        case .email: return "Email verified."
        }
    }

    /// What that screen says about it.
    var verifiedMessage: String {
        switch self {
        case .email: return "Your email has been verified."
        }
    }

    /// Whether `action` asks for this kind to be entered, or entered again to correct it.
    func isAskedFor(by action: NextAction) -> Bool {
        switch (self, action) {
        case (.email, .identifyEmail): return true
        default: return false
        }
    }

    /// The server's offer to send a code to this kind, when `action` is one.
    func challenge(in action: NextAction) -> SignupChallenge? {
        switch (self, action) {
        case let (.email, .challengeEmail(index, _)): return SignupChallenge(kind: .email, index: index)
        default: return nil
        }
    }
}

/// What the user typed for one kind.
struct SignupIdentifierValue: Equatable, Sendable {
    let kind: SignupIdentifierKind
    let value: String
}

/// A code the server will send. `index` is the server's, passed back unchanged.
struct SignupChallenge: Equatable, Sendable {
    let kind: SignupIdentifierKind
    let index: Int
}

/// What one sign-up requires, from `NextAction.signup(identifiers:)`.
struct SignupOffer: Equatable {
    /// The required kinds this flow can render.
    let required: [SignupIdentifierKind]
    /// The server requires a kind this flow has no screens for, so the sign-up can't be finished here.
    let requiresUnsupportedKind: Bool

    init(_ identifiers: [SignupIdentifier]) {
        required = identifiers.filter(\.isRequired).compactMap { SignupIdentifierKind($0.type) }
        requiresUnsupportedKind = identifiers.contains { $0.isRequired && SignupIdentifierKind($0.type) == nil }
    }

    /// Whether this flow can take the user to a created account. Exactly one identifier may be required until several
    /// are supported. An optional one is left out: the server lets the account be created without it.
    var isSupported: Bool { !requiresUnsupportedKind && required.count == 1 }
}

/// The server's `next`, read for sign-up.
struct SignupMenu: Equatable {
    /// Kinds the server will take an entry for. Includes one still being verified: entering it again corrects it.
    let askedFor: [SignupIdentifierKind]
    /// A code the server will send now, or again.
    let challenge: SignupChallenge?
    /// Every required identifier is verified: the account can be created.
    let canConfirm: Bool

    init(_ actions: [NextAction]) {
        askedFor = SignupIdentifierKind.allCases.filter { kind in actions.contains(where: kind.isAskedFor) }
        challenge = actions.lazy.compactMap { action in
            SignupIdentifierKind.allCases.lazy.compactMap { $0.challenge(in: action) }.first
        }.first
        canConfirm = actions.contains { if case .confirmSignup = $0 { return true } else { return false } }
    }
}

/// Where a sign-up stands after a code.
enum SignupProgress: Equatable {
    /// More registration steps, as the server lists them.
    case next(SignupMenu)
    /// The email already had an account, so the server signed that user in. The app has the credentials.
    case authenticated
}
