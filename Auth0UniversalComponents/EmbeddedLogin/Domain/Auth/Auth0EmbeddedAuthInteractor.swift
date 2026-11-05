import Auth0
import Foundation

// The Embedded Login adapter over Auth0: authorize → identify → challengeEmail or challengePhone → verifyOtp. When the
// tenant asks for more, it hands the server's next actions on in an `AdditionalStepContext` and goes no further.
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
    /// Reasons the SDK recognises by their `error_description` code get our own copy instead, since that
    /// code (e.g. `too_many_attempts`) isn't user-facing text.
    var displayMessage: String? {
        if let cause { return cause.localizedDescription }
        switch reason {
        case .tooManyWrongOtpAttempts, .tooManyAttempts, .tooManyLogins:
            return "Too many attempts. Please try again later."
        case .ipBlocked:
            return "Sign-in is temporarily blocked. Please try again later."
        case .consentRequired:
            return "This sign-in needs consent that can't be given in the app."
        case .insufficientAuthorization, .noEligibleFactors, .challengeExpired, .authorizationRejected:
            return nil
        default:
            if let description = info["error_description"] as? String, !description.isEmpty { return description }
            return nil
        }
    }
}

/// Async view of the authorize loop, so tests can stub it (`Request` can't be built outside Auth0).
@MainActor
protocol EmbeddedAuthClient {
    func authorize(connection: String) async throws
    func identify(_ identifier: String, type: IdentifierType) async throws
    func challengeEmail(index: Int) async throws
    func challengePhone(index: Int, deliveryMethod: PhoneDeliveryMethod) async throws
    func verifyOtp(_ code: String, type: OtpType) async throws -> Credentials
    func challengePush(index: Int) async throws
    func verifyOob() async throws -> Credentials
}

struct LiveEmbeddedAuthClient: EmbeddedAuthClient {
    /// The steps this flow itself has screens for: Email and SMS OTP.
    static let firstFactorCapabilities: [EmbeddedCapability] = [
        .identifyEmail, .challengeEmail, .identifyPhone, .challengePhone, .verifyOTP
    ]

    /// Auth0.swift's default scope.
    static let scope = "openid profile email offline_access"

    let auth: EmbeddedAuth
    /// What to advertise to `authorize`, so the server never routes to a step nothing can render.
    var capabilities: [EmbeddedCapability] = LiveEmbeddedAuthClient.firstFactorCapabilities

    func authorize(connection: String) async throws {
        try await auth.authorize(connection: connection,
                                 capabilities: capabilities,
                                 scope: Self.scope,
                                 audience: nil).start()
    }
    func identify(_ identifier: String, type: IdentifierType) async throws {
        try await auth.identify(identifier, type: type).start()
    }
    func challengeEmail(index: Int) async throws { try await auth.challengeEmail(index: index).start() }
    func challengePhone(index: Int, deliveryMethod: PhoneDeliveryMethod) async throws {
        try await auth.challengePhone(index: index, deliveryMethod: deliveryMethod).start()
    }
    func verifyOtp(_ code: String, type: OtpType) async throws -> Credentials {
        try await auth.verifyOtp(code, type: type).start()
    }
    func challengePush(index: Int) async throws { try await auth.challengePush(index: index).start() }
    func verifyOob() async throws -> Credentials { try await auth.verifyOob().start() }
}

/// Where a finished sign-in's credentials go. The SDK keeps nothing: the app that embeds the login receives them.
@MainActor
protocol CredentialsDelivering {
    /// Throws when the app can't take them; the sign-in then ends as "couldn't be saved".
    func deliver(credentials: Credentials) throws
}

/// One instance per login flow — `EmbeddedAuth` is stateful.
final class Auth0EmbeddedAuthInteractor: AuthInteracting {

    private let client: EmbeddedAuthClient
    private let credentialsDelivery: CredentialsDelivering
    private let connection: String?

    private var lastNextActions: [NextAction] = []
    /// Lets the first `startOTP` reuse the loop `discover()` opened.
    private var hasFreshLoop = false
    /// Where the last code went. An expired texted code is shown inline; an expired email code still goes full-screen.
    private var codeChannel: LoginChannel?

    init(client: EmbeddedAuthClient, credentialsDelivery: CredentialsDelivering, connection: String? = nil) {
        self.client = client
        self.credentialsDelivery = credentialsDelivery
        self.connection = connection
    }

    /// Reads `clientId`/`domain` from `Auth0.plist`. `additionalStepCapabilities` are the extra steps whatever runs the
    /// additional step can render; without any, a tenant that asks for more can't be served.
    convenience init(credentialsDelivery: CredentialsDelivering, session: URLSession = .shared, bundle: Bundle = .main,
                     connection: String? = nil, additionalStepCapabilities: [EmbeddedCapability] = []) {
        self.init(
            client: LiveEmbeddedAuthClient(
                auth: Auth0.embeddedAuth(session: session, bundle: bundle),
                capabilities: LiveEmbeddedAuthClient.firstFactorCapabilities + additionalStepCapabilities),
            credentialsDelivery: credentialsDelivery,
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

    @discardableResult
    func startOTP(connection: String, identifier: LoginIdentifier) async throws -> String? {
        if !hasFreshLoop {
            try await runStep { try await client.authorize(connection: connection) }
        }
        hasFreshLoop = false
        lastNextActions = []
        codeChannel = identifier.channel
        switch identifier {
        case let .email(email):
            try await runStep { try await client.identify(email, type: .email) }
            if let index = challengeEmailIndex {
                try await runStep { try await client.challengeEmail(index: index) }
            } else if !advertisesCode(on: .email) {
                throw AuthFailure.codeNotSent
            }
            return nil
        case let .phone(number):
            try await runStep { try await client.identify(number, type: .phone) }
            if let phone = textablePhone {
                try await runStep { try await client.challengePhone(index: phone.index, deliveryMethod: .text) }
                return smsDestination ?? phone.masked
            }
            // Already sent by the server, or a number that only takes voice calls, which this flow doesn't offer.
            guard advertisesCode(on: .sms) else { throw AuthFailure.codeNotSent }
            return smsDestination
        }
    }

    func verifyOTP(code: String) async throws -> AuthProgress {
        do {
            let credentials = try await client.verifyOtp(code, type: .oob)
            do {
                try credentialsDelivery.deliver(credentials: credentials)
            } catch {
                throw CredentialsNotSavedError()
            }
            return .authenticated
        } catch let error as EmbeddedAuthError {
            // More is required, but none of the user's factors can be used here: an empty menu says so.
            if case .noEligibleFactors = error.reason { return .additionalStepRequired(additionalStepContext([])) }
            // A texted code that timed out: Resend fixes it, so it stays on the code screen.
            if case .challengeExpired = error.reason, codeChannel == .phone { throw AuthFailure.codeExpired }
            guard case let .insufficientAuthorization(subReason, nextActions) = error.reason else {
                throw Self.failure(for: error)
            }
            lastNextActions = nextActions
            if subReason == .invalidCode || subReason == .invalidIdentifierOrCode {
                throw AuthFailure.invalidCode
            }
            // Only a plain continuation means the code is accepted and more is needed next.
            guard subReason == .none else { throw Auth0EmbeddedAuthError.requestFailed(message: nil) }
            return .additionalStepRequired(additionalStepContext(nextActions))
        }
    }

    /// The same sign-in session, for whatever continues it.
    private func additionalStepContext(_ nextActions: [NextAction]) -> AdditionalStepContext {
        AdditionalStepContext(nextActions: nextActions, client: client, credentialsDelivery: credentialsDelivery)
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

    private func advertisesCode(on channel: OtpChannel) -> Bool {
        lastNextActions.contains { if case .verifyOTP(channel, _) = $0 { return true } else { return false } }
    }

    private var challengeEmailIndex: Int? {
        for case let .challengeEmail(index, _) in lastNextActions { return index }
        return nil
    }

    /// The first of the user's phones that can take a text message, and its number as the server masked it.
    private var textablePhone: (index: Int, masked: String)? {
        for case let .challengePhone(index, masked, methods) in lastNextActions where methods.contains(.text) {
            return (index, masked)
        }
        return nil
    }

    /// The masked number the server says it texted.
    private var smsDestination: String? {
        for case let .verifyOTP(.sms, masked?) in lastNextActions { return masked }
        return nil
    }

    // MARK: SDK → engine mapping

    /// Rate limits stay inline (Resend reopens the loop); anything else goes full-screen.
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
        default:
            return .unsupported(String(describing: action))
        }
    }
}
