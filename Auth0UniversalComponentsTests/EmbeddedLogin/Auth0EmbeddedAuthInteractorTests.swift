@testable import Auth0UniversalComponents
import Auth0
import Foundation
import Testing

@Suite
@MainActor
struct Auth0EmbeddedAuthInteractorTests {

    private typealias F = EmbeddedAuthFixtures

    private let email = "sarah.doe@atko.email"
    private let client = StubEmbeddedAuthClient()
    private let store = StubCredentialsStore()

    private func makeSUT(connection: String? = "email") -> Auth0EmbeddedAuthInteractor {
        Auth0EmbeddedAuthInteractor(client: client, credentialsStore: store, connection: connection)
    }

    /// Scripts discovery → identify → challenge so `startOTP` lands on code entry.
    private func scriptEmailLoop() {
        client.authorizeResults = [F.needs([F.identifyEmail])]
        client.identifyResults = [F.needs([F.challengeEmail])]
        client.challengeEmailResults = [F.needs([F.verifyEmail])]
    }

    // MARK: Discovery

    @Test func discover_mapsUnknownActionToUnsupported() async throws {
        client.authorizeResults = [F.needs([F.identifyEmail, ["action": "action:passkey:v1"]])]
        let options = try await makeSUT().discover()
        #expect(options.first == .emailOTP(connection: "email"))
        #expect(options.count == 2)
        guard case .unsupported = options.last else { Issue.record("expected .unsupported"); return }
    }

    @Test func discover_withoutConnection_throws() async {
        await #expect(throws: Auth0EmbeddedAuthError.self) { try await makeSUT(connection: nil).discover() }
        #expect(client.calls.isEmpty)
    }

    // MARK: Email OTP

    @Test func discoverThenStartOTP_authorizesOnce() async throws {
        scriptEmailLoop()
        let sut = makeSUT()
        _ = try await sut.discover()
        try await sut.startOTP(connection: "email", email: email)
        #expect(client.calls == [.authorize(connection: "email"), .identify(email: email), .challengeEmail(index: 1)])
    }

    @Test func secondStartOTP_reopensLoop() async throws {
        scriptEmailLoop()
        let sut = makeSUT()
        _ = try await sut.discover()
        try await sut.startOTP(connection: "email", email: email)

        client.authorizeResults = [F.needs([F.identifyEmail])]
        client.identifyResults = [F.needs([F.challengeEmail])]
        try await sut.startOTP(connection: "email", email: email)
        #expect(Array(client.calls.suffix(3)) == [
            .authorize(connection: "email"), .identify(email: email), .challengeEmail(index: 1),
        ])
    }

    @Test func noEmailAction_throwsCodeNotSent() async throws {
        client.authorizeResults = [F.needs([F.identifyEmail])]
        client.identifyResults = [F.needs([])]
        let sut = makeSUT()
        _ = try await sut.discover()
        await #expect(throws: AuthFailure.codeNotSent) { try await sut.startOTP(connection: "email", email: email) }
    }

    @Test func verifyEmailWithoutChallenge_doesNotThrow() async throws {
        client.authorizeResults = [F.needs([F.identifyEmail])]
        client.identifyResults = [F.needs([F.verifyEmail])]
        let sut = makeSUT()
        _ = try await sut.discover()
        try await sut.startOTP(connection: "email", email: email)
        #expect(!client.calls.contains(.challengeEmail(index: 1)))
    }

    @Test func identifyRateLimited_throwsTooManyAttempts() async throws {
        client.authorizeResults = [F.needs([F.identifyEmail])]
        client.identifyResults = [F.terminal("too_many_requests", description: "too_many_attempts", statusCode: 429)]
        let sut = makeSUT()
        _ = try await sut.discover()
        await #expect(throws: AuthFailure.tooManyAttempts) { try await sut.startOTP(connection: "email", email: email) }
    }

    // MARK: Verify

    @Test func success_storesCredentials() async throws {
        client.verifyOtpResults = [.success(Credentials(accessToken: "at"))]
        try await makeSUT().verifyOTP(code: "112233")
        #expect(store.stored.map(\.accessToken) == ["at"])
        #expect(client.calls == [.verifyOtp(code: "112233", type: .oob)])
    }

    @Test func storeFailure_throwsCredentialsNotSaved() async {
        store.error = NSError(domain: "keychain", code: -25308)
        await #expect(throws: CredentialsNotSavedError()) { try await makeSUT().verifyOTP(code: "112233") }
    }

    @Test(arguments: ["invalid_code", "invalid_identifier_or_code"])
    func invalidCodeSubReason_throwsInvalidCode(_ subReason: String) async {
        client.verifyOtpResults = [.failure(F.needs([F.verifyEmail], subReason: subReason))]
        await #expect(throws: AuthFailure.invalidCode) { try await makeSUT().verifyOTP(code: "000000") }
    }

    @Test func tooManyWrongAttempts_throwsTooManyAttempts() async {
        client.verifyOtpResults = [.failure(F.terminal("access_denied", description: "too_many_wrong_otp_attempts"))]
        await #expect(throws: AuthFailure.tooManyAttempts) { try await makeSUT().verifyOTP(code: "000000") }
    }

    /// MFA step-up is out of scope: any second-factor request goes full-screen.
    @Test func stepUpRequested_throwsRequestFailed() async {
        client.verifyOtpResults = [.failure(F.needs([F.verifyTOTP, F.verifyEmail, F.verifySMS]))]
        await #expect(throws: Auth0EmbeddedAuthError.self) { try await makeSUT().verifyOTP(code: "112233") }
        #expect(store.stored.isEmpty)
    }
}
