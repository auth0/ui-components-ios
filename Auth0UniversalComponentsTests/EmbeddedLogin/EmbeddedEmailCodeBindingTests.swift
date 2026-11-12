@testable import Auth0UniversalComponents
import Auth0
import Foundation
import Testing

@Suite
@MainActor
struct EmbeddedEmailCodeBindingTests {

    private let menu: [NextAction] = [
        .challengePush(index: 0, name: "Sudhanshu's iPhone"),
        .challengePhone(index: 0, identifier: "(4**)***-*900", deliveryMethods: [.text]),
        .challengeEmail(index: 0, identifier: "s***@atko.email"),
        .challengeEmail(index: 3, identifier: "w***@atko.email"),
        .verifyOTP(channel: .totp, identifier: nil), .identifyEmail
    ]

    @Test func theBinding_offersEveryAddressTheServerOffers() {
        let offers = EmbeddedEmailCodeBinding().offers(in: menu)
        #expect(offers.map(\.id) == ["email:0", "email:3"])
        #expect(offers.map(\.label) == ["s***@atko.email", "w***@atko.email"])
        #expect(offers.map(\.reference) == [0, 3], "the server's index, not a position in the list")
        #expect(offers.allSatisfy { $0.factor == .email })
    }

    @Test func aMenuWithoutAnEmailChallenge_givesNoOffers() {
        #expect(EmbeddedEmailCodeBinding().offers(in: Array(menu.prefix(2))).isEmpty)
        #expect(EmbeddedEmailCodeBinding().offers(in: [.verifyOTP(channel: .email, identifier: nil)]).isEmpty,
                "asking for the code is not an offer to send one")
    }

    @Test func theBinding_advertisesWhatAnEmailCodeNeeds() {
        #expect(EmbeddedEmailCodeBinding().capabilities == [.challengeEmail, .verifyOTP])
    }

    @Test func theOtherBindings_ignoreTheEmailChallenge() {
        let only: [NextAction] = [.challengeEmail(index: 0, identifier: "s***@atko.email")]
        #expect(EmbeddedPushBinding().offers(in: only).isEmpty)
        #expect(EmbeddedPhoneCodeBinding(delivery: .text).offers(in: only).isEmpty)
        #expect(EmbeddedPhoneCodeBinding(delivery: .voice).offers(in: only).isEmpty)
    }

    /// Push first, then a text, then the emails, which keep the server's order among themselves.
    @Test func email_isListedAfterPushAndThePhone() {
        let step = EmbeddedMfaStep()
        let scrambled = [menu[2], menu[3], menu[1], menu[0]]
        let context = AdditionalStepContext(nextActions: scrambled, client: StubEmbeddedAuthClient(),
                                            credentialsDelivery: StubCredentialsDelivery())
        let session = step.makeSession(context: context, delegate: NoAdditionalStepDelegate())
        let controller = (session as? EmbeddedMfaSession)?.controller
        controller?.start()
        guard case let .authenticatorList(list)? = controller?.step else { Issue.record("no list"); return }
        #expect(list.rows.map(\.factor) == [.push, .sms, .email, .email])
        #expect(list.rows.suffix(2).map(\.title) == ["s***@atko.email", "w***@atko.email"])
        #expect(list.rows.suffix(2).map(\.subtitle) == ["Email", "Email"])
        #expect(list.rows.suffix(2).map(\.icon) == ["email", "email"])
    }
}

@MainActor
private final class NoAdditionalStepDelegate: AdditionalStepDelegate {
    func additionalStepDidFinish(_ result: AdditionalStepResult) {}
    func additionalStepRequestedRestart() {}
}

@Suite
@MainActor
struct EmbeddedEmailCodeTransportTests {

    private typealias Fix = EmbeddedAuthFixtures

    private let client = StubEmbeddedAuthClient()
    private let store = StubCredentialsDelivery()
    private let gate = EmbeddedRequestGate()
    private let stager: EmbeddedMfaStager
    private let offer = MfaFactorOffer(id: "email:2", factor: .email, label: "s***@atko.email", reference: 2)

    init() {
        stager = EmbeddedMfaStager(delivery: store)
    }

    private func challenge(index: Int) -> [String: Any] {
        ["action": "action:challenge:email:v1", "index": index, "identifier": "s***@atko.email"]
    }

    private func transport(menu: @escaping ([NextAction]) -> [MfaFactorOffer] = { _ in [] })
        -> EmbeddedEmailCodeTransport {
        EmbeddedEmailCodeTransport(client: client, stager: stager, gate: gate, menu: menu)
    }

    // MARK: Sending

    @Test func send_emailsTheCodeToTheOffersAddress() async throws {
        client.challengeEmailResults = [Fix.needs([Fix.verifyEmail, challenge(index: 2)])]
        let sut = transport()
        let sent = try await sut.sendCode(to: offer)
        #expect(client.calls == [.challengeEmail(index: 2)])
        #expect(sent == EmailCodeSent(canResend: true))
        #expect(gate.lastChallenge == "email:2")
        #expect(sut.isCodePending(for: offer), "nothing else was challenged since")
    }

    @Test func send_whenTheServerNoLongerOffersTheAddress_cannotBeResent() async throws {
        client.challengeEmailResults = [Fix.needs([Fix.verifyEmail, challenge(index: 5)])]
        #expect(try await transport().sendCode(to: offer) == EmailCodeSent(canResend: false))
    }

    @Test func send_withoutAskingForTheCode_isUnexpected() async {
        client.challengeEmailResults = [Fix.needs([challenge(index: 2)])]
        await #expect(throws: MfaError.unexpected(nil)) { try await transport().sendCode(to: offer) }
    }

    @Test func send_toAnOfferWithoutTheServersIndex_isUnexpected() async {
        let unindexed = MfaFactorOffer(id: "email:2", factor: .email, label: nil)
        await #expect(throws: MfaError.unexpected(nil)) { try await transport().sendCode(to: unindexed) }
        #expect(client.calls.isEmpty)
    }

    @Test func send_withoutAConnection_isANetworkError() async {
        client.challengeEmailResults = [Fix.network]
        await #expect(throws: MfaError.network) { try await transport().sendCode(to: offer) }
    }

    @Test func send_tooManyRequests_isReported() async {
        client.challengeEmailResults = [Fix.terminal("too_many_requests", description: "too_many_attempts",
                                                     statusCode: 429)]
        await #expect(throws: MfaError.tooManyAttempts) { try await transport().sendCode(to: offer) }
    }

    // MARK: Checking

    @Test func verify_acceptsTheCode_andStagesTheCredentials() async throws {
        client.verifyOtpResults = [.success(Credentials(accessToken: "email"))]
        let sut = transport()
        #expect(try await sut.verify(code: "123456", for: offer) == .verified)
        #expect(client.calls == [.verifyOtp(code: "123456", type: .oob)])
        #expect(store.delivered.isEmpty, "staged, not yet handed over: the Core decides")
        try stager.commit()
        #expect(store.delivered.map(\.accessToken) == ["email"])
    }

    @Test(arguments: ["invalid_code", "invalid_identifier_or_code"])
    func verify_aWrongCode_isRejected_andCanBeResentWhileTheAddressIsOffered(_ subReason: String) async throws {
        client.verifyOtpResults = [.failure(Fix.needs([Fix.verifyEmail, challenge(index: 2)], subReason: subReason))]
        #expect(try await transport().verify(code: "000000", for: offer) == .rejected(canResend: true))
    }

    @Test func verify_aWrongCode_cantBeResentWhenTheAddressIsNoLongerOffered() async throws {
        client.verifyOtpResults = [.failure(Fix.needs([Fix.verifyEmail, challenge(index: 7)],
                                                      subReason: "invalid_code"))]
        #expect(try await transport().verify(code: "000000", for: offer) == .rejected(canResend: false))
    }

    @Test func verify_thenAnotherFactor_readsTheWholeMenu() async throws {
        let next = [MfaFactorOffer(id: "push:0", factor: .push, label: "Sudhanshu's iPhone", reference: 0)]
        client.verifyOtpResults = [.failure(Fix.needs([Fix.challengePush]))]
        #expect(try await transport(menu: { _ in next }).verify(code: "123456", for: offer)
            == .anotherFactor(next))
    }

    @Test func verify_aPushAnswer_isUnexpected() async {
        client.verifyOtpResults = [.failure(Fix.needs([Fix.verifyOob()], subReason: "authorization_pending"))]
        await #expect(throws: MfaError.unexpected(nil)) { try await transport().verify(code: "123456", for: offer) }
    }

    @Test func verify_anExpiredCode_isReportedAsExpired() async {
        client.verifyOtpResults = [.failure(Fix.terminal("access_denied", description: "challenge_expired"))]
        await #expect(throws: MfaError.tokenExpired) { try await transport().verify(code: "123456", for: offer) }
    }

    @Test func verify_withoutAConnection_isANetworkError() async {
        client.verifyOtpResults = [.failure(Fix.network)]
        await #expect(throws: MfaError.network) { try await transport().verify(code: "123456", for: offer) }
    }

    @Test func verify_tooManyWrongCodes_endsTheFlow() async {
        client.verifyOtpResults = [.failure(Fix.terminal("access_denied", description: "too_many_wrong_otp_attempts"))]
        await #expect(throws: MfaError.tooManyAttempts) { try await transport().verify(code: "000000", for: offer) }
    }

    @Test func verify_isNotSent_whenTheUserLeft() async {
        await #expect(throws: CancellationError.self) {
            try await transport().verify(code: "123456", for: offer, while: { false })
        }
        #expect(client.calls.isEmpty)
    }
}

/// An emailed code as a multi-factor step through the whole stack, composed the way `EmbeddedLoginView` composes it:
/// the real login interactor and coordinator, the MFA adapter, the Core, and the push and email factors, against the
/// scripted SDK client.
@Suite
@MainActor
struct EmbeddedMfaEmailCodeEndToEndTests {

    private typealias Fix = EmbeddedAuthFixtures

    private let email = "sudhanshu.vohra@okta.com"
    private let client = StubEmbeddedAuthClient()
    private let store = StubCredentialsDelivery()

    /// An email challenge the way the server lists it as a second factor.
    private func emailOffer(index: Int = 2) -> [String: Any] {
        ["action": "action:challenge:email:v1", "index": index, "identifier": "s***@atko.email"]
    }

    /// Scripts discovery → email → challenge, then answers the sign-in's email code with `afterTheCode`. Push and the
    /// email factor are plugged in, with no resend wait.
    private func signIn(afterTheCode: EmbeddedAuthError) async -> LoginFlowCoordinator {
        client.authorizeResults = [Fix.needs([Fix.identifyEmail])]
        client.identifyResults = [Fix.needs([Fix.challengeEmail])]
        client.challengeEmailResults = [Fix.needs([Fix.verifyEmail])] + client.challengeEmailResults
        client.verifyOtpResults = [.failure(afterTheCode)] + client.verifyOtpResults
        let provider = EmbeddedMfaStep(clock: RecordingMfaClock(), bindings: [
            EmbeddedPushBinding(policy: PushPollingPolicy(resendCooldownSeconds: 0)),
            EmbeddedEmailCodeBinding(policy: EmailCodePolicy(resendCooldownSeconds: 0))
        ])
        let interactor = Auth0EmbeddedAuthInteractor(client: client, credentialsDelivery: store, connection: "email")
        let sut = LoginFlowCoordinator(interactor: interactor, additionalStep: provider)
        await sut.send(.start)
        await sut.send(.submitIdentifier(.email(email)))
        await sut.send(.submitOTP(code: "111111"))
        return sut
    }

    private func mfaStep(_ sut: LoginFlowCoordinator) -> MfaStep? {
        (sut.additionalStep as? EmbeddedMfaSession)?.controller.step
    }

    private func codeModel(_ sut: LoginFlowCoordinator) -> EmailCodeChallengeModel? {
        if case let .factor(step)? = mfaStep(sut) { return step.model as? EmailCodeChallengeModel }
        return nil
    }

    private func list(_ sut: LoginFlowCoordinator) -> AuthenticatorListModel? {
        if case let .authenticatorList(model)? = mfaStep(sut) { return model }
        return nil
    }

    /// What was sent after the sign-in's own email code.
    private var mfaCalls: [StubEmbeddedAuthClient.Call] {
        Array(client.calls.drop { $0 != .verifyOtp(code: "111111", type: .oob) }.dropFirst())
    }

    @Test func theOnlyFactor_emailsTheCodeAtOnce_andTheRightCodeSignsIn() async {
        client.challengeEmailResults = [Fix.needs([Fix.verifyEmail, emailOffer()])]
        client.verifyOtpResults = [.success(Credentials(accessToken: "email"))]

        let sut = await signIn(afterTheCode: Fix.needs([emailOffer()]))
        await eventually { codeModel(sut) != nil }
        guard let model = codeModel(sut) else { Issue.record("no code screen"); return }
        #expect(model.address == "s***@atko.email")
        #expect(model.canSwitch == false)
        #expect(mfaCalls == [.challengeEmail(index: 2)], "the server's index, sent at once")

        model.submit("123456")
        await eventually { sut.step == .authenticated }
        #expect(sut.step == .authenticated)
        #expect(mfaCalls.last == .verifyOtp(code: "123456", type: .oob))
        #expect(store.delivered.map(\.accessToken) == ["email"], "handed to the app once")
    }

    @Test func aWrongCode_staysOnTheCodeScreen_thenTheRightOneSignsIn() async {
        client.challengeEmailResults = [Fix.needs([Fix.verifyEmail, emailOffer()])]
        client.verifyOtpResults = [
            .failure(Fix.needs([Fix.verifyEmail, emailOffer()], subReason: "invalid_code")),
            .success(Credentials(accessToken: "email"))
        ]

        let sut = await signIn(afterTheCode: Fix.needs([emailOffer()]))
        await eventually { codeModel(sut) != nil }
        codeModel(sut)?.submit("000000")
        await eventually { codeModel(sut)?.isCodeRejected == true }
        #expect(sut.step == .additionalStep)
        #expect(store.delivered.isEmpty)

        codeModel(sut)?.submit("123456")
        await eventually { sut.step == .authenticated }
        #expect(store.delivered.map(\.accessToken) == ["email"])
    }

    @Test func pushAndEmail_areListed_pushFirst_andEmailCanBePicked() async {
        client.challengeEmailResults = [Fix.needs([Fix.verifyEmail, emailOffer()])]
        client.verifyOtpResults = [.success(Credentials(accessToken: "email"))]

        let sut = await signIn(afterTheCode: Fix.needs([emailOffer(), Fix.challengePush]))
        guard let rows = list(sut) else { Issue.record("no list"); return }
        #expect(rows.rows.map(\.id) == ["push:0", "email:2"])
        #expect(rows.rows.map(\.subtitle) == ["Push notification", "Email"])
        #expect(mfaCalls.isEmpty, "nothing is sent until the user picks")

        rows.select("email:2")
        await eventually { codeModel(sut) != nil }
        #expect(codeModel(sut)?.canSwitch == true)
        #expect(mfaCalls == [.challengeEmail(index: 2)])
        codeModel(sut)?.submit("123456")
        await eventually { sut.step == .authenticated }
        #expect(store.delivered.map(\.accessToken) == ["email"])
    }
}
