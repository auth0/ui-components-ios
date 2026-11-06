@testable import Auth0UniversalComponents
import Auth0
import Foundation
import Testing

/// SMS as a multi-factor step through the whole stack, composed the way `EmbeddedLoginView` composes it: the real
/// login interactor and coordinator, the MFA adapter, the Core, and the push and SMS factors, against the scripted SDK
/// client.
@Suite
@MainActor
// swiftlint:disable:next type_body_length
struct EmbeddedMfaPhoneCodeEndToEndTests {

    private typealias Fix = EmbeddedAuthFixtures

    private let email = "sudhanshu.vohra@okta.com"
    private let client = StubEmbeddedAuthClient()
    private let store = StubCredentialsDelivery()
    private let clock = RecordingMfaClock()

    /// Scripts discovery → email → challenge, then answers the email code with `afterTheCode`. Push and a phone
    /// code for each of `deliveries` are plugged in, with no resend wait unless `phoneWait` says so.
    private func signIn(afterTheCode: EmbeddedAuthError, deliveries: [PhoneCodeDelivery] = [.text],
                        phoneWait: Int = 0,
                        handler: ((MfaError) -> MfaErrorHandling)? = nil) async -> LoginFlowCoordinator {
        client.authorizeResults = [Fix.needs([Fix.identifyEmail])]
        client.identifyResults = [Fix.needs([Fix.challengeEmail])]
        client.challengeEmailResults = [Fix.needs([Fix.verifyEmail])] + client.challengeEmailResults
        client.verifyOtpResults = [.failure(afterTheCode)] + client.verifyOtpResults
        let phoneCodes = deliveries.map {
            EmbeddedPhoneCodeBinding(delivery: $0, policy: PhoneCodePolicy(resendCooldownSeconds: phoneWait))
        }
        let provider = EmbeddedMfaStep(clock: clock, bindings: [
            EmbeddedPushBinding(policy: PushPollingPolicy(resendCooldownSeconds: 0))
        ] + phoneCodes)
        provider.errorHandler = handler
        let interactor = Auth0EmbeddedAuthInteractor(client: client, credentialsDelivery: store, connection: "email")
        let sut = LoginFlowCoordinator(interactor: interactor, additionalStep: provider)
        await sut.send(.start)
        await sut.send(.submitIdentifier(.email(email)))
        await sut.send(.submitOTP(code: "111111"))
        return sut
    }

    private func menu(_ entries: [[String: Any]]) -> EmbeddedAuthError { Fix.needs(entries) }

    private func eventually(_ condition: () -> Bool) async {
        for _ in 0..<10_000 where !condition() { await Task.yield() }
    }

    private func mfaStep(_ sut: LoginFlowCoordinator) -> MfaStep? {
        (sut.additionalStep as? EmbeddedMfaSession)?.controller.step
    }

    private func codeModel(_ sut: LoginFlowCoordinator) -> PhoneCodeChallengeModel? {
        if case let .factor(step)? = mfaStep(sut) { return step.model as? PhoneCodeChallengeModel }
        return nil
    }

    private func list(_ sut: LoginFlowCoordinator) -> AuthenticatorListModel? {
        if case let .authenticatorList(model)? = mfaStep(sut) { return model }
        return nil
    }

    private var codeCalls: [StubEmbeddedAuthClient.Call] {
        client.calls.filter { call in
            switch call {
            case .challengePhone: return true
            case let .verifyOtp(code, _): return code != "111111"            // not the email code
            default: return false
            }
        }
    }

    /// The requests that ask for a code to be sent.
    private var sends: [StubEmbeddedAuthClient.Call] {
        codeCalls.filter { if case .challengePhone = $0 { return true } else { return false } }
    }

    // MARK: One phone

    @Test func onePhone_textsTheCodeAtOnce_andTheRightCodeSignsIn() async {
        client.challengePhoneResults = [Fix.needs([Fix.verifySMS, Fix.challengePhone()])]
        client.verifyOtpResults = [.success(Credentials(accessToken: "sms"))]

        let sut = await signIn(afterTheCode: menu([Fix.challengePhone(index: 3)]))
        await eventually { codeModel(sut) != nil }
        guard let model = codeModel(sut) else { Issue.record("no code screen"); return }
        #expect(model.destination == "(4**)***-*900")
        #expect(model.canSwitch == false)
        #expect(codeCalls == [.challengePhone(index: 3, deliveryMethod: .text)])

        model.submit("123456")
        await eventually { sut.step == .authenticated }
        #expect(sut.step == .authenticated)
        #expect(codeCalls.last == .verifyOtp(code: "123456", type: .oob))
        #expect(store.delivered.map(\.accessToken) == ["sms"], "handed to the app once")
    }

    @Test func aWrongCode_staysOnTheCodeScreen_thenTheRightOneSignsIn() async {
        client.challengePhoneResults = [Fix.needs([Fix.verifySMS, Fix.challengePhone()])]
        client.verifyOtpResults = [
            .failure(Fix.needs([Fix.verifySMS, Fix.challengePhone()], subReason: "invalid_code")),
            .success(Credentials(accessToken: "sms"))
        ]

        let sut = await signIn(afterTheCode: menu([Fix.challengePhone()]))
        await eventually { codeModel(sut) != nil }
        codeModel(sut)?.submit("000000")
        await eventually { codeModel(sut)?.isCodeRejected == true }
        #expect(sut.step == .additionalStep)
        #expect(store.delivered.isEmpty)

        codeModel(sut)?.submit("123456")
        await eventually { sut.step == .authenticated }
        #expect(store.delivered.map(\.accessToken) == ["sms"])
    }

    // MARK: Push and a texted code

    @Test func pushAndSms_areListed_pushFirst_andSmsCanBePicked() async {
        client.challengePhoneResults = [Fix.needs([Fix.verifySMS])]
        client.verifyOtpResults = [.success(Credentials(accessToken: "sms"))]

        let sut = await signIn(afterTheCode: menu([Fix.challengePhone(), Fix.challengePush]))
        guard let rows = list(sut) else { Issue.record("no list"); return }
        #expect(rows.rows.map(\.id) == ["push:0", "sms:0"])
        #expect(rows.rows.map(\.subtitle) == ["Push notification", "Text message"])
        #expect(codeCalls.isEmpty, "nothing is sent until the user picks")

        rows.select("sms:0")
        await eventually { codeModel(sut) != nil }
        #expect(codeModel(sut)?.canSwitch == true)
        codeModel(sut)?.submit("123456")
        await eventually { sut.step == .authenticated }
        #expect(store.delivered.map(\.accessToken) == ["sms"])
    }

    /// Verify another way: from the code screen back to the list, then push.
    @Test func fromSms_verifyAnotherWay_returnsToTheList() async {
        client.challengePhoneResults = [Fix.needs([Fix.verifySMS])]

        let sut = await signIn(afterTheCode: menu([Fix.challengePhone(), Fix.challengePush]))
        list(sut)?.select("sms:0")
        await eventually { codeModel(sut) != nil }
        codeModel(sut)?.switchFactor()
        await eventually { list(sut) != nil }
        #expect(list(sut)?.rows.count == 2)
    }

    // MARK: Failures that leave the code usable

    /// The texted code timed out: the code screen stays, Verify is off, and Resend sends a new one at once.
    @Test func anExpiredCode_staysOnTheCodeScreen_andResendSendsANewOne() async {
        client.challengePhoneResults = [Fix.needs([Fix.verifySMS, Fix.challengePhone()]),
                                        Fix.needs([Fix.verifySMS, Fix.challengePhone()])]
        client.verifyOtpResults = [
            .failure(Fix.terminal("access_denied", description: "challenge_expired")),
            .success(Credentials(accessToken: "sms"))
        ]

        let sut = await signIn(afterTheCode: menu([Fix.challengePhone()]))
        await eventually { codeModel(sut) != nil }
        codeModel(sut)?.submit("123456")
        await eventually { codeModel(sut)?.isCodeExpired == true }
        #expect(sut.step == .additionalStep, "no error screen")
        #expect(store.delivered.isEmpty)

        codeModel(sut)?.resend()
        await eventually { sends.count == 2 }
        await eventually { codeModel(sut)?.isCodeExpired == false }
        codeModel(sut)?.submit("654321")
        await eventually { sut.step == .authenticated }
        #expect(store.delivered.map(\.accessToken) == ["sms"])
    }

    /// The connection drops while a new code is requested: the code on the phone still works.
    @Test func aResendWithoutAConnection_keepsTheCodeScreen_andTheOldCodeStillSignsIn() async {
        client.challengePhoneResults = [Fix.needs([Fix.verifySMS, Fix.challengePhone()]), Fix.network]
        client.verifyOtpResults = [.success(Credentials(accessToken: "sms"))]

        let sut = await signIn(afterTheCode: menu([Fix.challengePhone()]))
        await eventually { codeModel(sut) != nil }
        codeModel(sut)?.resend()
        await eventually { codeModel(sut)?.requestError == .network }
        #expect(sut.step == .additionalStep, "no error screen")

        codeModel(sut)?.submit("123456")
        await eventually { sut.step == .authenticated }
        #expect(store.delivered.map(\.accessToken) == ["sms"])
    }

    /// Too many wrong codes locks the challenge: that still ends the flow.
    @Test func tooManyRequestsWhileChecking_stillEndsWithTheErrorScreen() async {
        client.challengePhoneResults = [Fix.needs([Fix.verifySMS])]
        client.verifyOtpResults = [.failure(Fix.terminal("too_many_requests", description: "too_many_attempts",
                                                         statusCode: 429))]

        let sut = await signIn(afterTheCode: menu([Fix.challengePhone()]))
        await eventually { codeModel(sut) != nil }
        codeModel(sut)?.submit("000000")
        await eventually { if case .error = mfaStep(sut) { return true } else { return false } }
        guard case let .error(model)? = mfaStep(sut) else { Issue.record("no error screen"); return }
        #expect(model.error == .tooManyAttempts)
    }

    // MARK: Leaving and coming back

    /// "Verify another way" and then the same phone again, inside the wait: the first code's screen returns, and no
    /// second text is sent.
    @Test func leavingAndComingBack_doesNotTextAnotherCode() async {
        clock.suspends = true                                  // the countdown stands still
        client.challengePhoneResults = [Fix.needs([Fix.verifySMS, Fix.challengePhone()])]

        let sut = await signIn(afterTheCode: menu([Fix.challengePhone(), Fix.challengePush]), phoneWait: 60)
        list(sut)?.select("sms:0")
        await eventually { codeModel(sut) != nil }
        codeModel(sut)?.switchFactor()
        await eventually { list(sut) != nil }

        list(sut)?.select("sms:0")
        await eventually { codeModel(sut) != nil }
        #expect(codeModel(sut)?.canResend == true)
        #expect(codeModel(sut)?.resendAvailableIn ?? 0 > 0, "the wait carried over")
        await settle()
        #expect(sends == [.challengePhone(index: 0, deliveryMethod: .text)], "one text, not two")
    }

    // MARK: Voice

    /// A phone the server can only call: the call goes out at once, and the spoken code signs in.
    @Test func aVoiceOnlyPhone_isCalledAtOnce_andTheRightCodeSignsIn() async {
        client.challengePhoneResults = [Fix.needs([Fix.verifyVoice, Fix.challengePhone(methods: ["voice"])])]
        client.verifyOtpResults = [.success(Credentials(accessToken: "voice"))]

        let sut = await signIn(afterTheCode: menu([Fix.challengePhone(index: 3, methods: ["voice"])]),
                               deliveries: [.text, .voice])
        await eventually { codeModel(sut) != nil }
        guard let model = codeModel(sut) else { Issue.record("no code screen"); return }
        #expect(model.delivery == .voice)
        #expect(model.destination == "(4**)***-*900")
        #expect(codeCalls == [.challengePhone(index: 3, deliveryMethod: .voice)])

        model.submit("123456")
        await eventually { sut.step == .authenticated }
        #expect(codeCalls.last == .verifyOtp(code: "123456", type: .oob))
        #expect(store.delivered.map(\.accessToken) == ["voice"])
    }

    /// A phone that takes both is listed twice, text first, with hidden digits drawn as `*`. Picking the call calls.
    @Test func aPhoneThatTakesBoth_isListedOncePerDelivery() async {
        client.challengePhoneResults = [Fix.needs([Fix.verifyVoice])]

        let sut = await signIn(afterTheCode: menu([Fix.challengePhone(masked: "+1XXXXXX900")]),
                               deliveries: [.text, .voice])
        guard let rows = list(sut) else { Issue.record("no list"); return }
        #expect(rows.rows.map(\.id) == ["sms:0", "voice:0"])
        #expect(rows.rows.map(\.title) == ["+1******900", "+1******900"])
        #expect(rows.rows.map(\.subtitle) == ["Text message", "Voice call"])

        rows.select("voice:0")
        await eventually { codeModel(sut) != nil }
        #expect(codeModel(sut)?.delivery == .voice)
        #expect(codeCalls == [.challengePhone(index: 0, deliveryMethod: .voice)])
    }

    // MARK: Email

    /// An address on offer is mailed at once, on the code screen the texted code uses, and the right code signs in.
    @Test func anEmailAddress_isMailedAtOnce_andTheRightCodeSignsIn() async {
        client.challengeEmailResults = [Fix.needs([Fix.verifyEmailTo, Fix.emailChallenge(index: 5)])]
        client.verifyOtpResults = [.success(Credentials(accessToken: "email"))]

        let sut = await signIn(afterTheCode: menu([Fix.emailChallenge(index: 5)]), deliveries: [.email])
        await eventually { codeModel(sut) != nil }
        guard let model = codeModel(sut) else { Issue.record("no code screen"); return }
        #expect(model.delivery == .email)
        #expect(model.destination == "sa**@atko.email")
        #expect(model.canSwitch == false)
        #expect(client.calls.filter { $0 == .challengeEmail(index: 5) }.count == 1)

        model.submit("123456")
        await eventually { sut.step == .authenticated }
        #expect(codeCalls.last == .verifyOtp(code: "123456", type: .oob))
        #expect(store.delivered.map(\.accessToken) == ["email"], "handed to the app once")
    }

    /// A wrong emailed code stays on the screen, and the right one then signs in.
    @Test func aWrongEmailedCode_staysOnTheCodeScreen() async {
        client.challengeEmailResults = [Fix.needs([Fix.verifyEmailTo, Fix.emailChallenge(index: 5)])]
        client.verifyOtpResults = [
            .failure(Fix.needs([Fix.verifyEmailTo, Fix.emailChallenge(index: 5)], subReason: "invalid_code")),
            .success(Credentials(accessToken: "email"))
        ]

        let sut = await signIn(afterTheCode: menu([Fix.emailChallenge(index: 5)]), deliveries: [.email])
        await eventually { codeModel(sut) != nil }
        codeModel(sut)?.submit("000000")
        await eventually { codeModel(sut)?.isCodeRejected == true }
        #expect(sut.step == .additionalStep)
        #expect(store.delivered.isEmpty)

        codeModel(sut)?.submit("123456")
        await eventually { sut.step == .authenticated }
        #expect(store.delivered.map(\.accessToken) == ["email"])
    }

    /// Resend mails a new code to the same address.
    @Test func resend_mailsANewCodeToTheSameAddress() async {
        client.challengeEmailResults = [Fix.needs([Fix.verifyEmailTo, Fix.emailChallenge(index: 5)]),
                                        Fix.needs([Fix.verifyEmailTo, Fix.emailChallenge(index: 5)])]

        let sut = await signIn(afterTheCode: menu([Fix.emailChallenge(index: 5)]), deliveries: [.email])
        await eventually { codeModel(sut) != nil }
        codeModel(sut)?.resend()
        await eventually { client.calls.filter { $0 == .challengeEmail(index: 5) }.count == 2 }
        #expect(sut.step == .additionalStep)
    }

    /// Push, a text, a call and an email on one menu: all four are listed, and the email can be picked.
    @Test func everyKindOfCode_isListed_pushFirst_andTheEmailCanBePicked() async {
        client.challengeEmailResults = [Fix.needs([Fix.verifyEmailTo])]
        client.verifyOtpResults = [.success(Credentials(accessToken: "email"))]

        let sut = await signIn(
            afterTheCode: menu([Fix.challengePhone(), Fix.emailChallenge(index: 5), Fix.challengePush]),
            deliveries: [.text, .voice, .email])
        guard let rows = list(sut) else { Issue.record("no list"); return }
        #expect(rows.rows.map(\.id) == ["push:0", "sms:0", "voice:0", "email:5"])
        #expect(rows.rows.map(\.subtitle) == ["Push notification", "Text message", "Voice call", "Email"])
        #expect(client.calls.filter { $0 == .challengeEmail(index: 5) }.isEmpty, "nothing is sent until the user picks")

        rows.select("email:5")
        await eventually { codeModel(sut) != nil }
        #expect(codeModel(sut)?.delivery == .email)
        #expect(codeModel(sut)?.canSwitch == true)
        codeModel(sut)?.submit("123456")
        await eventually { sut.step == .authenticated }
        #expect(store.delivered.map(\.accessToken) == ["email"])
    }

    // MARK: Nothing to send

    /// Without the voice factor plugged in, a phone that only takes calls isn't offered: with nothing else, MFA can't
    /// run here.
    @Test func aVoiceOnlyPhone_withoutTheVoiceFactor_isNotOffered() async {
        var reported: [MfaError] = []
        let sut = await signIn(afterTheCode: menu([Fix.challengePhone(methods: ["voice"])]),
                               handler: { reported.append($0); return .notHandled })
        await eventually { sut.step == .additionalStepUnavailable }
        #expect(sut.step == .additionalStepUnavailable)
        #expect(reported == [.noEligibleFactors])
        #expect(codeCalls.isEmpty)
    }

    // MARK: Ending

    @Test func tooManyWrongCodes_endsWithTheErrorScreen() async {
        client.challengePhoneResults = [Fix.needs([Fix.verifySMS])]
        client.verifyOtpResults = [.failure(Fix.terminal("access_denied", description: "too_many_wrong_otp_attempts"))]

        let sut = await signIn(afterTheCode: menu([Fix.challengePhone()]))
        await eventually { codeModel(sut) != nil }
        codeModel(sut)?.submit("000000")
        await eventually { if case .error = mfaStep(sut) { return true } else { return false } }
        guard case let .error(model)? = mfaStep(sut) else { Issue.record("no error screen"); return }
        #expect(model.error == .tooManyAttempts)
        #expect(store.delivered.isEmpty)
    }

    /// Back on the code screen cancels MFA: a fresh sign-in, and nothing reaches the app.
    @Test func back_cancelsSms_andReturnsToTheFirstScreen() async {
        client.challengePhoneResults = [Fix.needs([Fix.verifySMS])]

        let sut = await signIn(afterTheCode: menu([Fix.challengePhone()]))
        await eventually { codeModel(sut) != nil }
        sut.goBack()
        await eventually { sut.step == .collectOTPIdentifier(.email) }
        #expect(sut.step == .collectOTPIdentifier(.email))
        #expect(store.delivered.isEmpty)
    }
}
