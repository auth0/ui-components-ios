import Auth0
import Foundation

// The Embedded Login adapter over Auth0: authorize → identify → challengeEmail → verifyOtp, then Guardian
// push when the tenant asks for a second factor. Intermediate steps return `insufficient_authorization`
// with the `nextActions` to take. `EmbeddedAuthGuardianPushClient` is the only other Auth0-aware file.

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

/// Async view of the authorize loop, so tests can stub it (`Request` can't be built outside Auth0).
@MainActor
protocol EmbeddedAuthClient {
    func authorize(connection: String) async throws
    func identify(email: String) async throws
    func challengeEmail(index: Int) async throws
    func verifyOtp(_ code: String, type: OtpType) async throws -> Credentials
    func challengePush(index: Int) async throws
    func verifyOob() async throws -> Credentials
}

struct LiveEmbeddedAuthClient: EmbeddedAuthClient {
    /// The steps this flow has screens for, so the server never routes to one it can't render:
    /// Email OTP, then Guardian push.
    static let capabilities: [EmbeddedCapability] = [
        .identifyEmail, .challengeEmail, .verifyOTP,
        .challengePush, .verifyOob
    ]

    let auth: EmbeddedAuth

    func authorize(connection: String) async throws {
        try await auth.authorize(connection: connection,
                                 capabilities: Self.capabilities,
                                 scope: "openid profile email offline_access",
                                 audience: nil).start()
    }
    func identify(email: String) async throws { try await auth.identify(email, type: .email).start() }
    func challengeEmail(index: Int) async throws { try await auth.challengeEmail(index: index).start() }
    func verifyOtp(_ code: String, type: OtpType) async throws -> Credentials {
        try await auth.verifyOtp(code, type: type).start()
    }
    func challengePush(index: Int) async throws { try await auth.challengePush(index: index).start() }
    func verifyOob() async throws -> Credentials { try await auth.verifyOob().start() }
}

protocol CredentialsStoring {
    func store(credentials: Credentials) throws
}

extension CredentialsManager: CredentialsStoring {}

/// One instance per login flow — `EmbeddedAuth` is stateful.
final class Auth0EmbeddedAuthInteractor: AuthInteracting {

    private let client: EmbeddedAuthClient
    private let credentialsStore: CredentialsStoring
    private let connection: String?

    private var lastNextActions: [NextAction] = []
    /// Lets the first `startOTP` reuse the loop `discover()` opened.
    private var hasFreshLoop = false

    init(client: EmbeddedAuthClient, credentialsStore: CredentialsStoring, connection: String? = nil) {
        self.client = client
        self.credentialsStore = credentialsStore
        self.connection = connection
    }

    /// Reads `clientId`/`domain` from `Auth0.plist`.
    convenience init(session: URLSession = .shared, bundle: Bundle = .main, connection: String? = nil) {
        self.init(
            client: LiveEmbeddedAuthClient(auth: Auth0.embeddedAuth(session: session, bundle: bundle)),
            credentialsStore: CredentialsManager(authentication: Auth0.authentication(session: session, bundle: bundle)),
            connection: connection
        )
    }

    // MARK: AuthInteracting

    func discover() async throws -> [LoginOption] {
        guard let connection else { throw Auth0EmbeddedAuthError.discoveryConnectionMissing }
        try await runStep { try await client.authorize(connection: connection) }
        hasFreshLoop = true
        return lastNextActions.map { Self.option(for: $0, connection: connection) }
    }

    func startOTP(connection: String, email: String) async throws {
        if !hasFreshLoop {
            try await runStep { try await client.authorize(connection: connection) }
        }
        hasFreshLoop = false
        lastNextActions = []
        try await runStep { try await client.identify(email: email) }
        if let index = challengeEmailIndex {
            try await runStep { try await client.challengeEmail(index: index) }
        } else if !advertisesEmailCode {
            throw AuthFailure.codeNotSent
        }
    }

    func verifyOTP(code: String) async throws -> AuthProgress {
        do {
            let credentials = try await client.verifyOtp(code, type: .oob)
            do {
                try credentialsStore.store(credentials: credentials)
            } catch {
                throw CredentialsNotSavedError()
            }
            return .authenticated
        } catch let error as EmbeddedAuthError {
            guard case let .insufficientAuthorization(subReason, nextActions) = error.reason else {
                throw Self.failure(for: error)
            }
            lastNextActions = nextActions
            if subReason == .invalidCode || subReason == .invalidIdentifierOrCode {
                throw AuthFailure.invalidCode
            }
            // The email code is accepted and the tenant wants a second factor.
            return .guardianPush(EmbeddedAuthGuardianPushClient.devices(in: nextActions))
        }
    }

    func makeGuardianPushClient() -> AnyGuardianPushClient<Void> {
        let credentialsStore = self.credentialsStore
        return AnyGuardianPushClient(EmbeddedAuthGuardianPushClient(client: client)).mapApproval { credentials in
            do {
                try credentialsStore.store(credentials: credentials)
            } catch {
                throw GuardianPushFailure.other(message: CredentialsNotSavedError().errorDescription)
            }
        }
    }

    // MARK: Loop helpers

    /// Runs one intermediate step, keeping the advertised `nextActions`.
    private func runStep(_ step: () async throws -> Void) async throws {
        do {
            try await step()
        } catch let error as EmbeddedAuthError {
            guard case let .insufficientAuthorization(_, nextActions) = error.reason else {
                throw Self.failure(for: error)
            }
            lastNextActions = nextActions
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

    /// Rate limits stay inline (Resend reopens the loop); anything else goes full-screen.
    private static func failure(for error: EmbeddedAuthError) -> Error {
        switch error.reason {
        case .tooManyWrongOtpAttempts, .tooManyAttempts: return AuthFailure.tooManyAttempts
        default: return Auth0EmbeddedAuthError.requestFailed(message: error.displayMessage)
        }
    }

    private static func option(for action: NextAction, connection: String) -> LoginOption {
        switch action {
        case .identifyEmail, .verifyOTP(.email, _):
            return .emailOTP(connection: connection)
        default:
            return .unsupported(String(describing: action))
        }
    }
}
