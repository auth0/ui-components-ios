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
    private let store = StubCredentialsDelivery()

    private func makeSUT(connection: String? = "email") -> Auth0EmbeddedAuthInteractor {
        Auth0EmbeddedAuthInteractor(client: client, credentialsDelivery: store, connection: connection)
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
        try await sut.startOTP(connection: "email", identifier: .email(email))
        #expect(client.calls == [
            .authorize(connection: "email"), .identify(email, type: .email), .challengeEmail(index: 1)
        ])
    }

    @Test func secondStartOTP_reopensLoop() async throws {
        scriptEmailLoop()
        let sut = makeSUT()
        _ = try await sut.discover()
        try await sut.startOTP(connection: "email", identifier: .email(email))

        client.authorizeResults = [Fix.needs([Fix.identifyEmail])]
        client.identifyResults = [Fix.needs([Fix.challengeEmail])]
        try await sut.startOTP(connection: "email", identifier: .email(email))
        #expect(Array(client.calls.suffix(3)) == [
            .authorize(connection: "email"), .identify(email, type: .email), .challengeEmail(index: 1),
        ])
    }

    @Test func noEmailAction_throwsCodeNotSent() async throws {
        client.authorizeResults = [Fix.needs([Fix.identifyEmail])]
        client.identifyResults = [Fix.needs([])]
        let sut = makeSUT()
        _ = try await sut.discover()
        await #expect(throws: AuthFailure.codeNotSent) {
            try await sut.startOTP(connection: "email", identifier: .email(email))
        }
    }

    @Test func verifyEmailWithoutChallenge_doesNotThrow() async throws {
        client.authorizeResults = [Fix.needs([Fix.identifyEmail])]
        client.identifyResults = [Fix.needs([Fix.verifyEmail])]
        let sut = makeSUT()
        _ = try await sut.discover()
        try await sut.startOTP(connection: "email", identifier: .email(email))
        #expect(!client.calls.contains(.challengeEmail(index: 1)))
    }

    @Test func identifyRateLimited_throwsTooManyAttempts() async throws {
        client.authorizeResults = [Fix.needs([Fix.identifyEmail])]
        client.identifyResults = [Fix.terminal("too_many_requests", description: "too_many_attempts", statusCode: 429)]
        let sut = makeSUT()
        _ = try await sut.discover()
        await #expect(throws: AuthFailure.tooManyAttempts) {
            try await sut.startOTP(connection: "email", identifier: .email(email))
        }
    }

    // MARK: Verify

    @Test func success_handsTheCredentialsToTheApp() async throws {
        client.verifyOtpResults = [.success(Credentials(accessToken: "at"))]
        #expect(try await makeSUT().verifyOTP(code: "112233") == .authenticated)
        #expect(store.delivered.map(\.accessToken) == ["at"])
        #expect(client.calls == [.verifyOtp(code: "112233", type: .oob)])
    }

    @Test func appFailure_throwsCredentialsNotSaved() async {
        store.error = NSError(domain: "app", code: -25308)
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
        #expect(store.delivered.isEmpty)
    }

    /// The additional step continues the same sign-in: same client, same credentials delivery.
    @Test func theContext_carriesTheSameSignIn() async throws {
        client.verifyOtpResults = [.failure(Fix.needs([Fix.challengePush]))]
        let progress = try await makeSUT().verifyOTP(code: "112233")
        guard case let .additionalStepRequired(context) = progress else {
            Issue.record("expected an additional step")
            return
        }
        #expect((context.client as AnyObject) === client)
        #expect((context.credentialsDelivery as AnyObject) === store)
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

    /// On its own the login advertises only the steps it renders itself. Whatever plugs in adds its own.
    @Test func capabilities_onTheirOwn_coverEmailAndPhone() {
        #expect(LiveEmbeddedAuthClient.firstFactorCapabilities
                == [.identifyEmail, .challengeEmail, .identifyPhone, .challengePhone, .verifyOTP])
    }

    // MARK: SMS OTP

    private let phone = "+14233530900"

    @Test func discover_mapsPhoneToPhoneOTP() async throws {
        client.authorizeResults = [Fix.needs([Fix.identifyEmail, Fix.identifyPhone])]
        let options = try await makeSUT().discover()
        #expect(options == [.emailOTP(connection: "email"), .phoneOTP(connection: "email")])
    }

    /// The number is identified as a phone and the code is sent by text; the server's mask comes back for the screen.
    @Test func startOTP_phone_textsTheCode_andReturnsTheServersMask() async throws {
        client.authorizeResults = [Fix.needs([Fix.identifyPhone])]
        client.identifyResults = [Fix.needs([Fix.challengePhone(index: 2)])]
        client.challengePhoneResults = [Fix.needs([Fix.verifySMS])]
        let sut = makeSUT()
        _ = try await sut.discover()
        let sentTo = try await sut.startOTP(connection: "email", identifier: .phone(phone))
        #expect(client.calls == [
            .authorize(connection: "email"), .identify(phone, type: .phone),
            .challengePhone(index: 2, deliveryMethod: .text)
        ])
        #expect(sentTo == "+1***99")
    }

    /// Without a masked number in the code prompt, the phone's own mask is used.
    @Test func startOTP_phone_fallsBackToThePhonesMask() async throws {
        client.authorizeResults = [Fix.needs([Fix.identifyPhone])]
        client.identifyResults = [Fix.needs([Fix.challengePhone(masked: "(4**)***-*900")])]
        client.challengePhoneResults = [Fix.needs([["action": "action:verify:otp:v1", "channel": "sms"]])]
        let sut = makeSUT()
        _ = try await sut.discover()
        #expect(try await sut.startOTP(connection: "email", identifier: .phone(phone)) == "(4**)***-*900")
    }

    /// A server that hides digits with `X` gets them drawn as `*`, like every other mask: the code prompt's number,
    /// or the phone's own when the prompt names none.
    @Test(arguments: [("+1XXXXXX99", "+1******99"), (nil, "+1******900")] as [(String?, String)])
    func startOTP_phone_showsHiddenDigitsAsAsterisks(_ promptMask: String?, _ shown: String) async throws {
        var codePrompt: [String: Any] = ["action": "action:verify:otp:v1", "channel": "sms"]
        codePrompt["identifier"] = promptMask
        client.authorizeResults = [Fix.needs([Fix.identifyPhone])]
        client.identifyResults = [Fix.needs([Fix.challengePhone(masked: "+1xxxxxx900")])]
        client.challengePhoneResults = [Fix.needs([codePrompt])]
        let sut = makeSUT()
        _ = try await sut.discover()
        #expect(try await sut.startOTP(connection: "email", identifier: .phone(phone)) == shown)
    }

    @Test func startOTP_phone_usesTheFirstPhoneThatTakesTexts() async throws {
        client.authorizeResults = [Fix.needs([Fix.identifyPhone])]
        client.identifyResults = [Fix.needs([
            Fix.challengePhone(index: 0, methods: ["voice"]), Fix.challengePhone(index: 1, methods: ["text"])
        ])]
        let sut = makeSUT()
        _ = try await sut.discover()
        try await sut.startOTP(connection: "email", identifier: .phone(phone))
        #expect(client.calls.last == .challengePhone(index: 1, deliveryMethod: .text))
    }

    /// Voice calls aren't offered by this flow, so a voice-only number can't get a code here.
    @Test func startOTP_voiceOnlyPhone_throwsCodeNotSent() async throws {
        client.authorizeResults = [Fix.needs([Fix.identifyPhone])]
        client.identifyResults = [Fix.needs([Fix.challengePhone(methods: ["voice"])])]
        let sut = makeSUT()
        _ = try await sut.discover()
        await #expect(throws: AuthFailure.codeNotSent) {
            try await sut.startOTP(connection: "email", identifier: .phone(phone))
        }
        #expect(!client.calls.contains { if case .challengePhone = $0 { return true } else { return false } })
    }

    @Test func startOTP_phone_alreadyTexted_sendsNothingMore() async throws {
        client.authorizeResults = [Fix.needs([Fix.identifyPhone])]
        client.identifyResults = [Fix.needs([Fix.verifySMS])]
        let sut = makeSUT()
        _ = try await sut.discover()
        #expect(try await sut.startOTP(connection: "email", identifier: .phone(phone)) == "+1***99")
        #expect(client.calls == [.authorize(connection: "email"), .identify(phone, type: .phone)])
    }

    /// An expired texted code is shown on the code screen, where Resend fixes it.
    @Test func expiredTextedCode_isInline() async throws {
        client.authorizeResults = [Fix.needs([Fix.identifyPhone])]
        client.identifyResults = [Fix.needs([Fix.challengePhone()])]
        client.challengePhoneResults = [Fix.needs([Fix.verifySMS])]
        client.verifyOtpResults = [.failure(Fix.terminal("access_denied", description: "challenge_expired"))]
        let sut = makeSUT()
        _ = try await sut.discover()
        try await sut.startOTP(connection: "email", identifier: .phone(phone))
        await #expect(throws: AuthFailure.codeExpired) { try await sut.verifyOTP(code: "123456") }
    }

    /// An expired email code keeps today's full-screen error.
    @Test func expiredEmailCode_staysFullScreen() async throws {
        scriptEmailLoop()
        client.verifyOtpResults = [.failure(Fix.terminal("access_denied", description: "challenge_expired"))]
        let sut = makeSUT()
        _ = try await sut.discover()
        try await sut.startOTP(connection: "email", identifier: .email(email))
        await #expect(throws: Auth0EmbeddedAuthError.self) { try await sut.verifyOTP(code: "123456") }
    }
}
