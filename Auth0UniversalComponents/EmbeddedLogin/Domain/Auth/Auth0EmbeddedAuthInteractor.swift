import Auth0
import Foundation

// The Embedded Login adapter over Auth0: authorize → identify → challengeEmail or challengePhone → verifyOtp, or
// identify(username) → verifyPassword. When the tenant asks for more, it hands the server's next actions on in an
// `AdditionalStepContext` and goes no further. Intermediate steps return `insufficient_authorization` with the
// `nextActions` to take.

enum Auth0EmbeddedAuthError: LocalizedError {
    case discoveryConnectionMissing
    /// `message` is `nil` when the SDK error carries no user-facing text.
    case requestFailed(message: String?)

    var errorDescription: String? {
        switch self {
        case .discoveryConnectionMissing: return "No connection is configured to start sign-in with."
        case let .requestFailed(message): return message
        }
    }
}

/// One instance per login flow — `EmbeddedAuth` is stateful.
final class Auth0EmbeddedAuthInteractor: AuthInteracting {

    private let client: EmbeddedAuthClient
    private let credentialsDelivery: CredentialsDelivering
    private let connection: String?
    private let preference: EmbeddedLoginPreference

    private var loop: SignInLoop = .closed
    /// What the server offered last.
    private var lastNextActions: [NextAction] = []

    init(client: EmbeddedAuthClient, credentialsDelivery: CredentialsDelivering, connection: String? = nil,
         preference: EmbeddedLoginPreference = .server) {
        self.client = client
        self.credentialsDelivery = credentialsDelivery
        self.connection = connection
        self.preference = preference
    }

    /// Reads `clientId`/`domain` from `Auth0.plist`. `additionalStepCapabilities` are the extra steps whatever runs the
    /// additional step can render; without any, a tenant that asks for more can't be served.
    convenience init(credentialsDelivery: CredentialsDelivering, session: URLSession = .shared, bundle: Bundle = .main,
                     connection: String? = nil, preference: EmbeddedLoginPreference = .server,
                     additionalStepCapabilities: [EmbeddedCapability] = []) {
        self.init(
            client: LiveEmbeddedAuthClient(
                auth: Auth0.embeddedAuth(session: session, bundle: bundle),
                capabilities: LiveEmbeddedAuthClient.capabilities(adding: additionalStepCapabilities)),
            credentialsDelivery: credentialsDelivery,
            connection: connection,
            preference: preference
        )
    }

    // MARK: AuthInteracting

    func discover() async throws -> [LoginOption] {
        guard let connection else { throw Auth0EmbeddedAuthError.discoveryConnectionMissing }
        try await runStep { try await client.authorize(connection: connection) }
        loop = .opened(nil)
        return lastNextActions.map { Self.option(for: $0, connection: connection) }
    }

    func identify(connection: String, identifier: LoginIdentifier) async throws -> IdentifierOutcome {
        try await submit(SignInIdentity(identifier: identifier, connection: connection))
        let password = lastNextActions.firstIndex(of: .verifyPassword)
        let code = lastNextActions.firstIndex { offersCode($0, to: identifier) }
        switch (code, password) {
        case let (code?, password?):
            return codeLeads(codeAt: code, passwordAt: password)
                ? .codeOffered(canUsePassword: true) : .passwordOffered(canSendCode: true)
        case (nil, _?):
            return .passwordOffered(canSendCode: false)
        default:
            // A username has nothing after it but a password: the server offering none is the same as a wrong one.
            if case .username = identifier { throw AuthFailure.invalidPassword }
            return .codeOffered(canUsePassword: false)
        }
    }

    @discardableResult
    func startOTP(connection: String, identifier: LoginIdentifier) async throws -> String? {
        let identity = SignInIdentity(identifier: identifier, connection: connection)
        let destination: String?
        switch identifier {
        case .email:
            try await continueOrReopen(identity)
            destination = try await sendEmailCode()
        case .phone:
            try await continueOrReopen(identity)
            destination = try await sendTextCode()
        case .username:
            // A username is followed by a password, not a code.
            throw Auth0EmbeddedAuthError.requestFailed(message: nil)
        }
        loop = .codeSent(identity)
        return destination
    }

    func verifyOTP(code: String) async throws -> AuthProgress {
        // The code belongs to a sign-in the server ended (too many wrong codes, a timeout): only a new code helps.
        if case .ended = loop { throw AuthFailure.codeNoLongerValid }
        return try await settle(attempt: { try await client.verifyOtp(code, type: .oob) }, rejection: rejectedCode)
    }

    func verifyPassword(_ password: String) async throws -> AuthProgress {
        // Anything but a sign-in the server has identified (it ended on a rate limit, a breach or a timeout, or a
        // re-open stopped half way) gets a new one for the same person first.
        if let identity = loop.identity, !loop.isReadyForPassword { try await submit(identity) }
        do {
            return try await settle(attempt: { try await client.verifyPassword(password) },
                                    rejection: Self.rejectedPassword)
        } catch AuthFailure.invalidPassword {
            // Alive, but the server now offers nothing but the password.
            if case let .identified(identity) = loop { loop = .passwordOnly(identity) }
            throw AuthFailure.invalidPassword
        }
    }

    private func sendEmailCode() async throws -> String? {
        if let index = challengeEmailIndex {
            try await runStep { try await client.challengeEmail(index: index) }
        } else if !advertisesCode(on: .email) {
            throw AuthFailure.codeNotSent
        }
        return nil
    }

    private func sendTextCode() async throws -> String? {
        if let phone = textablePhone {
            try await runStep { try await client.challengePhone(index: phone.index, deliveryMethod: .text) }
            return smsDestination ?? phone.masked
        }
        // Already sent by the server, or a number that only takes voice calls, which this flow doesn't offer.
        guard advertisesCode(on: .sms) else { throw AuthFailure.codeNotSent }
        return smsDestination
    }

    /// What the user can fix on the code screen: a wrong code, or a texted code that timed out (Resend fixes it, so it
    /// stays on the code screen).
    private func rejectedCode(_ error: EmbeddedAuthError) -> AuthFailure? {
        if case .challengeExpired = error.reason, case let .codeSent(identity) = loop,
           identity.identifier.channel == .phone {
            return .codeExpired
        }
        if case let .insufficientAuthorization(reason, _) = error.reason,
           reason == .invalidCode || reason == .invalidIdentifierOrCode {
            return .invalidCode
        }
        return nil
    }

    /// What the user can fix on the password screen: a wrong username or password, which the server doesn't tell apart.
    private static func rejectedPassword(_ error: EmbeddedAuthError) -> AuthFailure? {
        if case .insufficientAuthorization(.invalidIdentifierOrPassword, _) = error.reason { return .invalidPassword }
        return nil
    }

    /// Hands the credentials to the app, or says where the sign-in stands. `rejection` picks out what the user can fix
    /// on the screen they are on; anything else the server answers is a step to take next or an error.
    private func settle(attempt: () async throws -> Credentials,
                        rejection: (EmbeddedAuthError) -> AuthFailure?) async throws -> AuthProgress {
        do {
            let credentials = try await attempt()
            loop = .closed
            do {
                try credentialsDelivery.deliver(credentials: credentials)
            } catch {
                throw CredentialsNotSavedError()
            }
            return .authenticated
        } catch let error as EmbeddedAuthError {
            // Read before the error is applied to the sign-in: it looks at where the code went.
            let rejected = rejection(error)
            // More is required, but none of the user's factors can be used here: an empty menu says so.
            if case .noEligibleFactors = error.reason {
                loop = .closed
                return .additionalStepRequired(additionalStepContext([]))
            }
            record(error)
            if let rejected {
                if case let .insufficientAuthorization(_, nextActions) = error.reason { lastNextActions = nextActions }
                throw rejected
            }
            guard case let .insufficientAuthorization(subReason, nextActions) = error.reason else {
                throw Self.failure(for: error)
            }
            lastNextActions = nextActions
            // Only a plain continuation means the first factor is accepted and more is needed next.
            guard subReason == .none else { throw Auth0EmbeddedAuthError.requestFailed(message: nil) }
            loop = .closed
            return .additionalStepRequired(additionalStepContext(nextActions))
        }
    }

    /// The same sign-in session, for whatever continues it.
    private func additionalStepContext(_ nextActions: [NextAction]) -> AdditionalStepContext {
        AdditionalStepContext(nextActions: nextActions, client: client, credentialsDelivery: credentialsDelivery)
    }

    // MARK: Loop helpers

    /// `identify` is good for one code: a code right after it goes on the same sign-in, and anything else (a resend, or
    /// a code after a wrong password or an ended sign-in) starts over.
    private func continueOrReopen(_ identity: SignInIdentity) async throws {
        if loop != .identified(identity) { try await submit(identity) }
    }

    /// Opens the sign-in (the one `discover()` opened, the first time) and submits who it is for, keeping what the
    /// server asks for next.
    private func submit(_ identity: SignInIdentity) async throws {
        if !loop.isOpened {
            try await runStep { try await client.authorize(connection: identity.connection) }
        }
        // From here a failure still knows who this is for, so the next try can open it again.
        loop = .opened(identity)
        lastNextActions = []
        let identifier = identity.identifier
        try await runStep { try await client.identify(identifier.value, type: identifier.identifierType) }
        loop = .identified(identity)
    }

    /// Runs one intermediate step, keeping the advertised `nextActions`.
    private func runStep(_ step: () async throws -> Void) async throws {
        do {
            try await step()
        } catch let error as EmbeddedAuthError {
            record(error)
            guard case let .insufficientAuthorization(_, nextActions) = error.reason else {
                throw Self.failure(for: error)
            }
            lastNextActions = nextActions
        }
    }

    /// The SDK's rule: a continuation or a network error leaves the sign-in alive; any other failure ends it, and every
    /// later call fails with `no_active_session`.
    private func record(_ error: EmbeddedAuthError) {
        switch error.reason {
        case .insufficientAuthorization, .network:
            return
        default:
            loop = loop.identity.map(SignInLoop.ended) ?? .closed
        }
    }

    /// Both are offered: the app's preference decides which leads, else the order the server listed them in.
    private func codeLeads(codeAt code: Int, passwordAt password: Int) -> Bool {
        switch preference {
        case .code: return true
        case .password: return false
        case .server: return code < password
        }
    }

    private func advertisesCode(on channel: OtpChannel) -> Bool {
        lastNextActions.contains { if case .verifyOTP(channel, _) = $0 { return true } else { return false } }
    }

    /// Whether `action` is how a code gets to this email or number: asking for it, or the server having sent it
    /// already. A number that only takes calls isn't: this flow doesn't offer them.
    private func offersCode(_ action: NextAction, to identifier: LoginIdentifier) -> Bool {
        switch (action, identifier) {
        case (.challengeEmail, .email), (.verifyOTP(.email, _), .email): return true
        case let (.challengePhone(_, _, methods), .phone): return methods.contains(.text)
        case (.verifyOTP(.sms, _), .phone): return true
        default: return false
        }
    }

    private var challengeEmailIndex: Int? {
        for case let .challengeEmail(index, _) in lastNextActions { return index }
        return nil
    }

    /// The first of the user's phones that can take a text message, and its number as the server masked it, with
    /// each hidden digit as `*`.
    private var textablePhone: (index: Int, masked: String)? {
        for case let .challengePhone(index, masked, methods) in lastNextActions where methods.contains(.text) {
            return (index, PhoneMask.display(masked))
        }
        return nil
    }

    /// The masked number the server says it texted, with each hidden digit as `*`.
    private var smsDestination: String? {
        for case let .verifyOTP(.sms, masked?) in lastNextActions { return PhoneMask.display(masked) }
        return nil
    }

    // MARK: SDK → engine mapping

    /// Rate limits stay inline, where the next try opens a new sign-in; anything else goes full-screen.
    private static func failure(for error: EmbeddedAuthError) -> Error {
        switch error.reason {
        case .tooManyWrongOtpAttempts, .tooManyAttempts, .tooManyLogins: return AuthFailure.tooManyAttempts
        default: return Auth0EmbeddedAuthError.requestFailed(message: error.displayMessage)
        }
    }

    private static func option(for action: NextAction, connection: String) -> LoginOption {
        switch action {
        case .identifyEmail, .verifyOTP(.email, _):
            return .emailOTP(connection: connection)
        case .identifyPhone, .verifyOTP(.sms, _):
            return .phoneOTP(connection: connection)
        case .identifyUsername:
            return .password(connection: connection)
        default:
            return .unsupported(String(describing: action))
        }
    }
}

private extension LoginIdentifier {
    var identifierType: IdentifierType {
        switch self {
        case .email: return .email
        case .phone: return .phone
        case .username: return .username
        }
    }
}
