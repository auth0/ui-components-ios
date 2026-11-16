@testable import Auth0UniversalComponents
import Auth0
import Foundation

/// A scripted client that also follows the SDK's rule for the sign-in session: only a continuation
/// (`insufficient_authorization`) or a network error leaves it alive. Any other failure ends it, and every later call
/// except `authorize`, which opens a new one, fails on the device with `no_active_session`. `StubEmbeddedAuthClient`
/// can't tell: it answers whatever is next in its script, so a test of a retry never sees a session die.
@MainActor
final class SessionAwareEmbeddedAuthClient: EmbeddedAuthClient {

    /// What the server says, and what was called.
    let scripted = StubEmbeddedAuthClient()
    private(set) var hasSession = false

    var calls: [StubEmbeddedAuthClient.Call] { scripted.calls }

    /// Clears the session first, as the SDK does: a new one exists only if the server answers with a continuation.
    func authorize(connection: String) async throws {
        hasSession = false
        do {
            try await scripted.authorize(connection: connection)
            hasSession = true
        } catch {
            hasSession = Self.isContinuation(error)
            throw error
        }
    }

    func identify(_ identifier: String, type: IdentifierType) async throws {
        try await run { try await scripted.identify(identifier, type: type) }
    }

    func challengeEmail(index: Int) async throws {
        try await run { try await scripted.challengeEmail(index: index) }
    }

    func challengePhone(index: Int, deliveryMethod: PhoneDeliveryMethod) async throws {
        try await run { try await scripted.challengePhone(index: index, deliveryMethod: deliveryMethod) }
    }

    func verifyOtp(_ code: String, type: OtpType) async throws -> Credentials {
        try await run { try await scripted.verifyOtp(code, type: type) }
    }

    func verifyPassword(_ password: String) async throws -> Credentials {
        try await run { try await scripted.verifyPassword(password) }
    }

    func challengePush(index: Int) async throws {
        try await run { try await scripted.challengePush(index: index) }
    }

    func verifyOob() async throws -> Credentials {
        try await run { try await scripted.verifyOob() }
    }

    func verifyRecoveryCode(_ code: String) async throws {
        try await run { try await scripted.verifyRecoveryCode(code) }
    }

    func confirmRecoveryCode() async throws -> Credentials {
        try await run { try await scripted.confirmRecoveryCode() }
    }

    /// A call needs a session; a failure that isn't a continuation or a network error ends it. A call refused for want
    /// of a session never reaches the script.
    private func run<T>(_ call: () async throws -> T) async throws -> T {
        guard hasSession else { throw EmbeddedAuthFixtures.noActiveSession }
        do {
            return try await call()
        } catch {
            if !Self.keepsSession(after: error) { hasSession = false }
            throw error
        }
    }

    private static func keepsSession(after error: Error) -> Bool {
        guard let error = error as? EmbeddedAuthError else { return false }
        switch error.reason {
        case .insufficientAuthorization, .network: return true
        default: return false
        }
    }

    private static func isContinuation(_ error: Error) -> Bool {
        guard let error = error as? EmbeddedAuthError else { return false }
        if case .insufficientAuthorization = error.reason { return true }
        return false
    }
}
