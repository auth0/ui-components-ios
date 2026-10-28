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

    /// A second factor without Guardian push leaves no device, which the push screen shows as unavailable.
    /// A second factor without Guardian push (e.g. only TOTP or SMS) isn't one this flow can run.
    @Test func stepUpWithoutPush_isUnavailable() async throws {
        client.verifyOtpResults = [.failure(Fix.needs([Fix.verifyTOTP, Fix.verifyEmail, Fix.verifySMS]))]
        #expect(try await makeSUT().verifyOTP(code: "112233") == .secondFactorUnavailable)
        #expect(store.stored.isEmpty)
    }

    /// MFA is required but the user has no eligible factor: the same outcome, not a full-screen retry.
    @Test func noEligibleFactors_isUnavailable() async throws {
        client.verifyOtpResults = [.failure(Fix.terminal("access_denied", description: "no_eligible_factors"))]
        #expect(try await makeSUT().verifyOTP(code: "112233") == .secondFactorUnavailable)
    }

    /// Only a plain continuation is a second factor; a pending or slow-down answer here is unexpected.
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

    /// The login screen was dismissed: an approval that still arrives stores nothing.
    @Test func pushApproval_afterTheInteractorIsGone_storesNothing() async throws {
        client.verifyOobResults = [.success(Credentials(accessToken: "push"))]
        var interactor: Auth0EmbeddedAuthInteractor? = makeSUT()
        let push = interactor!.makeGuardianPushClient()
        weak var weakInteractor = interactor
        interactor = nil
        #expect(weakInteractor == nil)

        guard case .approved = try await push.checkApproval() else { Issue.record("expected approval"); return }
        #expect(store.stored.isEmpty)
    }

    @Test func stepUpWithPush_offersTheGuardianDevices() async throws {
        client.verifyOtpResults = [.failure(Fix.needs([Fix.verifyTOTP, Fix.challengePush]))]
        #expect(try await makeSUT().verifyOTP(code: "112233")
                == .guardianPush([GuardianPushDevice(index: 0, name: "Sudhanshu's iPhone")]))
    }

    @Test func pushApproval_storesTheCredentials() async throws {
        client.verifyOobResults = [.success(Credentials(accessToken: "push"))]
        // The coordinator keeps its interactor alive for the whole sign-in.
        let interactor = makeSUT()
        let push = interactor.makeGuardianPushClient()

        guard case .approved = try await push.checkApproval() else { Issue.record("expected approval"); return }
        #expect(store.stored.map(\.accessToken) == ["push"])
        withExtendedLifetime(interactor) {}
    }

    @Test func pushApproval_whenTheKeychainFails_isAFailure() async {
        client.verifyOobResults = [.success(Credentials())]
        store.error = NSError(domain: "keychain", code: -25308)
        let interactor = makeSUT()
        let push = interactor.makeGuardianPushClient()

        await #expect(throws: GuardianPushFailure.other(message: CredentialsNotSavedError().errorDescription)) {
            try await push.checkApproval()
        }
        withExtendedLifetime(interactor) {}
    }

    /// The server only offers steps this flow can render: Email OTP, then Guardian push.
    @Test func capabilities_coverEmailAndPushOnly() {
        #expect(LiveEmbeddedAuthClient.capabilities == [
            .identifyEmail, .challengeEmail, .verifyOTP, .challengePush, .verifyOob
        ])
    }
}
