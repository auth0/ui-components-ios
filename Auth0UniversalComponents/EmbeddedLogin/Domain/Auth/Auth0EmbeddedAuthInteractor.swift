#if AUTH0_EMBEDDED_AUTH
import Auth0
import Foundation

// The only file that imports Auth0: authorize → identify → challengeEmail → verifyOtp.
// Intermediate steps return `insufficient_authorization` with the `nextActions` to take.

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

extension EmbeddedAuthError {
    /// The cause's own description (e.g. "The Internet connection appears to be offline."), else the
    /// server's `error_description`. The SDK's `errorDescription` is debug text and isn't shown.
    var displayMessage: String? {
        if let cause { return cause.localizedDescription }
        if let description = info["error_description"] as? String, !description.isEmpty { return description }
        return nil
    }
}

/// One instance per login flow — `EmbeddedAuth` is stateful.
final class Auth0EmbeddedAuthInteractor: AuthInteracting {

    private let embeddedAuth: EmbeddedAuth
    private lazy var credentialsManager = CredentialsManager(authentication: authentication)
    private let authentication: Authentication
    private let connection: String?

    private var lastNextActions: [NextAction] = []
    /// Lets the first `startOTP` reuse the loop `discover()` opened.
    private var hasFreshLoop = false

    init(embeddedAuth: EmbeddedAuth, authentication: Authentication, connection: String? = nil) {
        self.embeddedAuth = embeddedAuth
        self.authentication = authentication
        self.connection = connection
    }

    /// Reads `clientId`/`domain` from `Auth0.plist`.
    convenience init(session: URLSession = .shared, bundle: Bundle = .main, connection: String? = nil) {
        self.init(
            embeddedAuth: Auth0.embeddedAuth(session: session, bundle: bundle),
            authentication: Auth0.authentication(session: session, bundle: bundle),
            connection: connection
        )
    }

    // MARK: AuthInteracting

    func discover() async throws -> [LoginOption] {
        guard let connection else { throw Auth0EmbeddedAuthError.discoveryConnectionMissing }
        try await runStep { embeddedAuth.authorize(connection: connection) }
        hasFreshLoop = true
        return lastNextActions.map { Self.option(for: $0, connection: connection) }
    }

    func startOTP(connection: String, email: String) async throws {
        if !hasFreshLoop {
            try await runStep { embeddedAuth.authorize(connection: connection) }
        }
        hasFreshLoop = false
        lastNextActions = []
        try await runStep { embeddedAuth.identify(email, type: .email) }
        if let index = challengeEmailIndex {
            try await runStep { embeddedAuth.challengeEmail(index: index) }
        } else if !advertisesEmailCode {
            throw AuthFailure.codeNotSent
        }
    }

    func verifyOTP(code: String) async throws -> AuthOutcome {
        try await verify(code, type: .oob)
    }

    func verifyMFA(code: String, factor: MFAFactor) async throws -> AuthOutcome {
        try await verify(code, type: factor == .otp ? .totp : .oob)
    }

    // MARK: Loop helpers

    /// Runs one intermediate step, keeping the advertised `nextActions`.
    private func runStep(_ makeRequest: () -> Request<Void, EmbeddedAuthError>) async throws {
        do {
            try await makeRequest().start()
        } catch let error as EmbeddedAuthError {
            guard case let .insufficientAuthorization(_, nextActions) = error.reason else {
                throw Auth0EmbeddedAuthError.requestFailed(message: error.displayMessage)
            }
            lastNextActions = nextActions
        }
    }

    private func verify(_ code: String, type: OtpType) async throws -> AuthOutcome {
        do {
            let credentials = try await embeddedAuth.verifyOtp(code, type: type).start()
            try? credentialsManager.store(credentials: credentials)
            return .authenticated
        } catch let error as EmbeddedAuthError {
            guard case let .insufficientAuthorization(subReason, nextActions) = error.reason else {
                throw Auth0EmbeddedAuthError.requestFailed(message: error.displayMessage)
            }
            lastNextActions = nextActions
            // Checked first so a re-presented code step isn't mistaken for a step-up.
            if subReason == .invalidCode || subReason == .invalidIdentifierOrCode {
                throw AuthFailure.invalidCode
            }
            if let challenge = Self.challenge(from: nextActions) {
                return .mfaRequired(challenge)
            }
            throw Auth0EmbeddedAuthError.requestFailed(message: error.displayMessage)
        }
    }

    private var advertisesEmailCode: Bool {
        lastNextActions.contains { if case .verifyOTP(.email, _) = $0 { return true } else { return false } }
    }

    private var challengeEmailIndex: Int? {
        for case let .challengeEmail(index, _) in lastNextActions { return index }
        return nil
    }

    // MARK: SDK → engine mapping

    private static func option(for action: NextAction, connection: String) -> LoginOption {
        switch action {
        case .identifyEmail, .verifyOTP(.email, _):
            return .emailOTP(connection: connection)
        default:
            return .unsupported(String(describing: action))
        }
    }

    /// SMS and voice are unsupported.
    private static func challenge(from nextActions: [NextAction]) -> MFAChallenge? {
        for case let .verifyOTP(channel, identifier) in nextActions {
            switch channel {
            case .email: return MFAChallenge(factor: .email, destination: identifier)
            case .totp:  return MFAChallenge(factor: .otp, destination: identifier)
            case .sms, .voice: continue
            }
        }
        return nil
    }
}
#endif
