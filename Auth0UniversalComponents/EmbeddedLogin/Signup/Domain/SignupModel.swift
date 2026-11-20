import Auth0

// What a sign-up is made of, and how the server's menu (`next`) is read. This is the only file that looks inside a
// `NextAction` for sign-up (apart from the delivery methods `CodeDelivery` maps), so a new kind of identifier changes
// it and the screens, and nothing in between.

/// What a new account can be identified by. A kind the server offers that isn't here is left out, so the flow never
/// shows a screen it can't finish. Adding one is a new case: the compiler then lists each place that needs it.
enum SignupIdentifierKind: CaseIterable, Hashable, Sendable {
    case email
    case phone

    /// `nil` for a kind this flow has no screens for.
    init?(_ type: IdentifierType) {
        switch type {
        case .email: self = .email
        case .phone: self = .phone
        case .username: return nil
        }
    }

    /// The steps the server must be able to offer for this kind, so `authorize` never advertises one with no screen.
    var capabilities: [EmbeddedCapability] {
        switch self {
        case .email: return [.identifyEmail, .challengeEmail, .verifyOTP]
        case .phone: return [.identifyPhone, .challengePhone, .verifyOTP]
        }
    }

    var identifierType: IdentifierType {
        switch self {
        case .email: return .email
        case .phone: return .phone
        }
    }

    /// What the user is verifying, as the words under a code screen say it ("sent to your email").
    var noun: String {
        switch self {
        case .email: return "email"
        case .phone: return "phone"
        }
    }

    /// The same, as the thing the user typed ("the email address is correct").
    var fullNoun: String {
        switch self {
        case .email: return "email address"
        case .phone: return "phone number"
        }
    }

    /// Whether a code that timed out can be replaced from the code screen, which starts the sign-up over for the same
    /// identifier. A kind without it ends the sign-up instead.
    var recoversExpiredCode: Bool {
        switch self {
        case .email: return false
        case .phone: return true
        }
    }

    /// Whether `action` asks for this kind to be entered, or entered again to correct it.
    func isAskedFor(by action: NextAction) -> Bool {
        switch (self, action) {
        case (.email, .identifyEmail), (.phone, .identifyPhone): return true
        default: return false
        }
    }

    /// The server's offer to send a code to this kind, when `action` is one.
    func challenge(in action: NextAction) -> SignupChallenge? {
        switch (self, action) {
        case let (.email, .challengeEmail(index, _)): return SignupChallenge(index: index)
        case let (.phone, .challengePhone(index, masked, methods)):
            return SignupChallenge(index: index, sentTo: PhoneMask.display(masked),
                                   deliveries: CodeDelivery.allCases.filter { delivery in
                                       methods.contains { CodeDelivery($0) == delivery }
                                   })
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
    let index: Int
    /// Where the server says the code goes, as it masked it. `nil` shows what the user typed.
    let sentTo: String?
    /// The ways the server will send it, in the order the screen offers them.
    let deliveries: [CodeDelivery]

    init(index: Int, sentTo: String? = nil, deliveries: [CodeDelivery] = [.email]) {
        self.index = index
        self.sentTo = sentTo
        self.deliveries = deliveries
    }

    /// The first code goes by text when the number takes one, and by a call when it only takes calls.
    var firstDelivery: CodeDelivery? { deliveries.contains(.text) ? .text : deliveries.first }
}

/// What one sign-up requires, from `NextAction.signup(identifiers:)`.
struct SignupOffer: Equatable {
    /// The sign-up the server's menu offers, or `nil` when it offers none.
    init?(in actions: [NextAction]) {
        for case let .signup(identifiers) in actions {
            self.init(identifiers)
            return
        }
        return nil
    }

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

    /// `preferring` are the kinds the sign-up requires: the ones asked for first, since a connection that requires a
    /// phone and allows an email must not start on the email.
    init(_ actions: [NextAction], preferring preferred: [SignupIdentifierKind] = []) {
        let asked = SignupIdentifierKind.allCases.filter { kind in actions.contains(where: kind.isAskedFor) }
        askedFor = asked.filter(preferred.contains) + asked.filter { !preferred.contains($0) }
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
