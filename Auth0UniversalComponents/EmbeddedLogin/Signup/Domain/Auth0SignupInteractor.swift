import Auth0
import Foundation

/// Sign-up over Auth0's Embedded Authorize loop: authorize → signup → identify → challenge → verify → confirm. Every
/// step but the last answers with `insufficient_authorization` and the `nextActions` to take, which is read as the
/// next menu.
final class Auth0SignupInteractor: SignupInteracting {

    private let client: EmbeddedAuthClient
    private let credentialsDelivery: CredentialsDelivering
    private let connection: String?
    /// The kinds this sign-up requires, so a menu that asks for more than one starts on a required one.
    private var required: [SignupIdentifierKind] = []

    init(client: EmbeddedAuthClient, credentialsDelivery: CredentialsDelivering, connection: String? = nil) {
        self.client = client
        self.credentialsDelivery = credentialsDelivery
        self.connection = connection
    }

    /// Reads `clientId`/`domain` from `Auth0.plist`.
    convenience init(credentialsDelivery: CredentialsDelivering, session: URLSession = .shared, bundle: Bundle = .main,
                     connection: String? = nil) {
        let auth = Auth0.embeddedAuth(session: session, bundle: bundle)
        self.init(client: LiveEmbeddedAuthClient(auth: auth, capabilities: Self.capabilities),
                  credentialsDelivery: credentialsDelivery, connection: connection)
    }

    /// Sign-up's own steps, then each kind's, once each. Nothing is advertised that has no screen.
    static var capabilities: [EmbeddedCapability] {
        var all: [EmbeddedCapability] = [.signup, .confirmSignup]
        for capability in SignupIdentifierKind.allCases.flatMap(\.capabilities) where !all.contains(capability) {
            all.append(capability)
        }
        return all
    }

    // MARK: SignupInteracting

    func open() async throws -> SignupMenu {
        guard let connection else { throw Auth0EmbeddedAuthError.discoveryConnectionMissing }
        let initial = try await nextActions { try await client.authorize(connection: connection) }
        guard let offer = SignupOffer(in: initial), offer.isSupported else { throw SignupUnavailable() }
        required = offer.required
        return menu(try await nextActions { try await client.signup() })
    }

    func identify(_ identifier: SignupIdentifierValue) async throws -> SignupMenu {
        let type = identifier.kind.identifierType
        return menu(try await nextActions { try await client.identify(identifier.value, type: type) })
    }

    func sendCode(_ challenge: SignupChallenge, via delivery: CodeDelivery) async throws {
        _ = try await nextActions {
            switch delivery {
            case .email: try await client.challengeEmail(index: challenge.index)
            case .text: try await client.challengePhone(index: challenge.index, deliveryMethod: .text)
            case .voice: try await client.challengePhone(index: challenge.index, deliveryMethod: .voice)
            }
        }
    }

    func verify(code: String) async throws -> SignupProgress {
        do {
            // Credentials here mean the email already had an account: the server signed that user in.
            try deliver(try await client.verifyOtp(code, type: .oob))
            return .authenticated
        } catch let error as EmbeddedAuthError {
            return .next(menu(try Self.continuation(of: error)))
        }
    }

    func confirm() async throws {
        do {
            try deliver(try await client.confirmSignup())
        } catch let error as EmbeddedAuthError {
            // A continuation here means the tenant wants more than sign-up gave (a second factor, say), which this
            // flow doesn't run. Sending the confirmation again would get the same answer.
            _ = try Self.continuation(of: error)
            throw SignupFailure.ended
        }
    }

    // MARK: Helpers

    private func menu(_ actions: [NextAction]) -> SignupMenu {
        SignupMenu(actions, preferring: required)
    }

    /// Runs one step that always answers with the next menu, and returns it.
    private func nextActions(after step: () async throws -> Void) async throws -> [NextAction] {
        do {
            try await step()
            throw Auth0EmbeddedAuthError.requestFailed(message: nil)    // ended without asking for anything
        } catch let error as EmbeddedAuthError {
            return try Self.continuation(of: error)
        }
    }

    /// A continuation's menu, or the failure it stands for. Only a request that never arrived is left: the session is
    /// still there, so it goes full screen with "Try again". The server's own words are shown only for a transport
    /// error, never for anything it said.
    private static func continuation(of error: EmbeddedAuthError) throws -> [NextAction] {
        if let failure = SignupFailure(error) { throw failure }
        guard case let .insufficientAuthorization(_, nextActions) = error.reason else {
            throw Auth0EmbeddedAuthError.requestFailed(message: error.cause is URLError ? error.displayMessage : nil)
        }
        return nextActions
    }

    private func deliver(_ credentials: Credentials) throws {
        do {
            try credentialsDelivery.deliver(credentials: credentials)
        } catch {
            throw CredentialsNotSavedError()
        }
    }
}
