@testable import Auth0UniversalComponents
import Auth0
import Foundation
import Testing

@Suite
@MainActor
struct Auth0EmbeddedAuthInteractorTests {

    private typealias Fix = EmbeddedAuthFixtures

    private let email = "sarah.doe@atko.email"
    private let client = StubEmbeddedAuthClient()
    private let store = StubCredentialsStore()

    private func makeSUT(connection: String? = "email") -> Auth0EmbeddedAuthInteractor {
        Auth0EmbeddedAuthInteractor(client: client, credentialsStore: store, connection: connection)
    }

    /// Scripts discovery → identify → challenge so `startOTP` lands on code entry.
    private func scriptEmailLoop() {
        client.authorizeResults = [Fix.needs([Fix.identifyEmail])]
        client.identifyResults = [Fix.needs([Fix.challengeEmail])]
        client.challengeEmailResults = [Fix.needs([Fix.verifyEmail])]
    }

    // MARK: Discovery

    @Test func discover_mapsUnknownActionToUnsupported() async throws {
        client.authorizeResults = [Fix.needs([Fix.identifyEmail, ["action": "action:passkey:v1"]])]
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

        client.authorizeResults = [Fix.needs([Fix.identifyEmail])]
        client.identifyResults = [Fix.needs([Fix.challengeEmail])]
        try await sut.startOTP(connection: "email", email: email)
        #expect(Array(client.calls.suffix(3)) == [
            .authorize(connection: "email"), .identify(email: email), .challengeEmail(index: 1),
        ])
    }

    @Test func noEmailAction_throwsCodeNotSent() async throws {
        client.authorizeResults = [Fix.needs([Fix.identifyEmail])]
        client.identifyResults = [Fix.needs([])]
        let sut = makeSUT()
        _ = try await sut.discover()
        await #expect(throws: AuthFailure.codeNotSent) { try await sut.startOTP(connection: "email", email: email) }
    }

    @Test func verifyEmailWithoutChallenge_doesNotThrow() async throws {
        client.authorizeResults = [Fix.needs([Fix.identifyEmail])]
        client.identifyResults = [Fix.needs([Fix.verifyEmail])]
        let sut = makeSUT()
        _ = try await sut.discover()
        try await sut.startOTP(connection: "email", email: email)
        #expect(!client.calls.contains(.challengeEmail(index: 1)))
    }

    @Test func identifyRateLimited_throwsTooManyAttempts() async throws {
        client.authorizeResults = [Fix.needs([Fix.identifyEmail])]
        client.identifyResults = [Fix.terminal("too_many_requests", description: "too_many_attempts", statusCode: 429)]
        let sut = makeSUT()
        _ = try await sut.discover()
        await #expect(throws: AuthFailure.tooManyAttempts) { try await sut.startOTP(connection: "email", email: email) }
    }

    // MARK: Verify

    @Test func success_storesCredentials() async throws {
        client.verifyOtpResults = [.success(Credentials(accessToken: "at"))]
        #expect(try await makeSUT().verifyOTP(code: "112233") == .authenticated)
        #expect(store.stored.map(\.accessToken) == ["at"])
        #expect(client.calls == [.verifyOtp(code: "112233", type: .oob)])
    }

    @Test func storeFailure_throwsCredentialsNotSaved() async {
        store.error = NSError(domain: "keychain", code: -25308)
        await #expect(throws: CredentialsNotSavedError()) { try await makeSUT().verifyOTP(code: "112233") }
    }

    @Test(arguments: ["invalid_code", "invalid_identifier_or_code"])
    func invalidCodeSubReason_throwsInvalidCode(_ subReason: String) async {
        client.verifyOtpResults = [.failure(Fix.needs([Fix.verifyEmail], subReason: subReason))]
        await #expect(throws: AuthFailure.invalidCode) { try await makeSUT().verifyOTP(code: "000000") }
    }

    @Test func tooManyWrongAttempts_throwsTooManyAttempts() async {
        client.verifyOtpResults = [.failure(Fix.terminal("access_denied", description: "too_many_wrong_otp_attempts"))]
        await #expect(throws: AuthFailure.tooManyAttempts) { try await makeSUT().verifyOTP(code: "000000") }
    }

    /// Whatever the server offers goes on to the additional step untouched: the interactor doesn't judge what is
    /// usable.
    @Test func stepUp_handsTheServersMenuOn_andStoresNothing() async throws {
        let menu = [Fix.verifyTOTP, Fix.verifyEmail, Fix.verifySMS, Fix.challengePush]
        client.verifyOtpResults = [.failure(Fix.needs(menu))]
        let progress = try await makeSUT().verifyOTP(code: "112233")
        guard case let .additionalStepRequired(context) = progress else {
            Issue.record("expected an additional step")
            return
        }
        #expect(context.nextActions.count == 4)
        #expect(store.stored.isEmpty)
    }

    /// The additional step continues the same sign-in: same client, same credentials store.
    @Test func theContext_carriesTheSameSignIn() async throws {
        client.verifyOtpResults = [.failure(Fix.needs([Fix.challengePush]))]
        let progress = try await makeSUT().verifyOTP(code: "112233")
        guard case let .additionalStepRequired(context) = progress else {
            Issue.record("expected an additional step")
            return
        }
        #expect((context.client as AnyObject) === client)
        #expect((context.credentialsStore as AnyObject) === store)
    }

    /// More is required but the user has no eligible factor: an empty menu, not a full-screen retry.
    @Test func noEligibleFactors_isAnEmptyMenu() async throws {
        client.verifyOtpResults = [.failure(Fix.terminal("access_denied", description: "no_eligible_factors"))]
        let progress = try await makeSUT().verifyOTP(code: "112233")
        guard case let .additionalStepRequired(context) = progress else {
            Issue.record("expected an additional step")
            return
        }
        #expect(context.nextActions.isEmpty)
    }

    /// Only a plain continuation means more is needed; a pending or slow-down answer here is unexpected.
    @Test(arguments: ["authorization_pending", "slow_down"])
    func unexpectedContinuation_isAnErrorWithoutRawText(_ subReason: String) async {
        client.verifyOtpResults = [.failure(Fix.needs([Fix.challengePush], subReason: subReason))]
        await #expect(throws: Auth0EmbeddedAuthError.self) { try await makeSUT().verifyOTP(code: "112233") }
        do {
            _ = try await makeSUT().verifyOTP(code: "112233")
        } catch {
            #expect((error as? LocalizedError)?.errorDescription == nil)
        }
    }

    @Test func tooManyLogins_isInline() async {
        client.verifyOtpResults = [
            .failure(Fix.terminal("too_many_requests", description: "too_many_logins", statusCode: 429))
        ]
        await #expect(throws: AuthFailure.tooManyAttempts) { try await makeSUT().verifyOTP(code: "000000") }
    }

    /// On its own the login advertises only the step it renders itself. Whatever plugs in adds its own.
    @Test func capabilities_onTheirOwn_coverEmailOnly() {
        #expect(LiveEmbeddedAuthClient.firstFactorCapabilities == [.identifyEmail, .challengeEmail, .verifyOTP])
    }
}
