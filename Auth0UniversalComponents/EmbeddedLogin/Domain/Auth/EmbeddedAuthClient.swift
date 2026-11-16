import Auth0
import Foundation

/// Async view of the authorize loop, so tests can stub it (`Request` can't be built outside Auth0).
@MainActor
protocol EmbeddedAuthClient {
    func authorize(connection: String) async throws
    func identify(_ identifier: String, type: IdentifierType) async throws
    func challengeEmail(index: Int) async throws
    func challengePhone(index: Int, deliveryMethod: PhoneDeliveryMethod) async throws
    func verifyOtp(_ code: String, type: OtpType) async throws -> Credentials
    func verifyPassword(_ password: String) async throws -> Credentials
    func challengePush(index: Int) async throws
    func verifyOob() async throws -> Credentials
    func verifyRecoveryCode(_ code: String) async throws
    func confirmRecoveryCode() async throws -> Credentials
}

struct LiveEmbeddedAuthClient: EmbeddedAuthClient {
    /// The steps this flow itself has screens for: Email and SMS OTP, and a username with its password.
    static let firstFactorCapabilities: [EmbeddedCapability] = [
        .identifyEmail, .challengeEmail, .identifyPhone, .challengePhone, .verifyOTP, .identifyUsername, .verifyPassword
    ]

    /// The login's own steps, then the additional step's, each once: they can overlap (both can text a code).
    static func capabilities(adding additional: [EmbeddedCapability]) -> [EmbeddedCapability] {
        var all: [EmbeddedCapability] = []
        for capability in firstFactorCapabilities + additional where !all.contains(capability) {
            all.append(capability)
        }
        return all
    }

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
    func verifyPassword(_ password: String) async throws -> Credentials {
        try await auth.verifyPassword(password).start()
    }
    func challengePush(index: Int) async throws { try await auth.challengePush(index: index).start() }
    func verifyOob() async throws -> Credentials { try await auth.verifyOob().start() }
    func verifyRecoveryCode(_ code: String) async throws { try await auth.verifyRecoveryCode(code).start() }
    func confirmRecoveryCode() async throws -> Credentials { try await auth.confirmRecoveryCode().start() }
}

/// Where a finished sign-in's credentials go. The SDK keeps nothing: the app that embeds the login receives them.
@MainActor
protocol CredentialsDelivering {
    /// Throws when the app can't take them; the sign-in then ends as "couldn't be saved".
    func deliver(credentials: Credentials) throws
}
