@testable import Auth0UniversalComponents
import Auth0
import Foundation
import Testing

@Suite
@MainActor
struct EmbeddedTotpBindingTests {

    private let menu: [NextAction] = [
        .challengePush(index: 0, name: "iPhone"),
        .challengePhone(index: 0, identifier: "(4**)***-*900", deliveryMethods: [.text]),
        .verifyOTP(channel: .totp, identifier: nil), .verifyOTP(channel: .sms, identifier: "+1***99")
    ]

    @Test func theBinding_offersTheAuthenticatorApp_whenTheServerAsksForItsCode() {
        let offers = EmbeddedTotpBinding().offers(in: menu)
        #expect(offers.map(\.id) == ["totp"])
        #expect(offers.map(\.factor) == [.totp])
        #expect(offers.map(\.label) == [nil], "the app is the user's own: no number or device to name")
    }

    @Test func aMenuWithoutTheAppsCode_givesNoOffers() {
        #expect(EmbeddedTotpBinding().offers(in: Array(menu.prefix(2))).isEmpty)
        #expect(EmbeddedTotpBinding().offers(in: [.verifyOTP(channel: .sms, identifier: nil), .verifyRecoveryCode])
            .isEmpty)
    }

    @Test func theBinding_advertisesWhatACodeNeeds() {
        #expect(EmbeddedTotpBinding().capabilities == [.verifyOTP])
    }

    @Test func theOtherBindings_ignoreTheAppsCode() {
        let only: [NextAction] = [.verifyOTP(channel: .totp, identifier: nil)]
        #expect(EmbeddedPushBinding().offers(in: only).isEmpty)
        #expect(EmbeddedPhoneCodeBinding(delivery: .text).offers(in: only).isEmpty)
        #expect(EmbeddedPhoneCodeBinding(delivery: .voice).offers(in: only).isEmpty)
    }

    /// Push first (it can't be phished), then the app (a typed code that never travels over the phone network), then a
    /// text.
    @Test func theApp_isListedAfterPush_andBeforeThePhone() {
        let step = EmbeddedMfaStep()
        let context = AdditionalStepContext(nextActions: menu.reversed(), client: StubEmbeddedAuthClient(),
                                            credentialsDelivery: StubCredentialsDelivery())
        let session = step.makeSession(context: context, delegate: NoAdditionalStepDelegate())
        let controller = (session as? EmbeddedMfaSession)?.controller
        controller?.start()
        guard case let .authenticatorList(list)? = controller?.step else { Issue.record("no list"); return }
        #expect(list.rows.map(\.factor) == [.push, .totp, .sms])
        let row = list.rows[1]
        #expect(row.title == "Authenticator app")
        #expect(row.subtitle == "Enter a code from your authenticator app.")
        #expect(row.icon == "totp")
    }
}

@MainActor
private final class NoAdditionalStepDelegate: AdditionalStepDelegate {
    func additionalStepDidFinish(_ result: AdditionalStepResult) {}
    func additionalStepRequestedRestart() {}
}

@Suite
@MainActor
struct EmbeddedTotpTransportTests {

    private typealias Fix = EmbeddedAuthFixtures

    private let client = StubEmbeddedAuthClient()
    private let store = StubCredentialsDelivery()

    private func transport(menu: @escaping ([NextAction]) -> [MfaFactorOffer] = { _ in [] })
        -> (EmbeddedTotpTransport, EmbeddedMfaStager) {
        let stager = EmbeddedMfaStager(delivery: store)
        return (EmbeddedTotpTransport(client: client, stager: stager, gate: EmbeddedRequestGate(), menu: menu), stager)
    }

    @Test func verify_checksTheCodeAsAnAuthenticatorAppsCode_andStagesTheCredentials() async throws {
        client.verifyOtpResults = [.success(Credentials(accessToken: "totp"))]
        let (sut, stager) = transport()
        #expect(try await sut.verify(code: "123456", while: { true }) == .verified)
        #expect(client.calls == [.verifyOtp(code: "123456", type: .totp)])
        #expect(store.delivered.isEmpty, "staged, not yet handed over: the Core decides")
        try stager.commit()
        #expect(store.delivered.map(\.accessToken) == ["totp"])
    }

    @Test(arguments: ["invalid_code", "invalid_identifier_or_code"])
    func verify_aWrongCode_isRejected(_ subReason: String) async throws {
        client.verifyOtpResults = [.failure(Fix.needs([Fix.verifyTOTP], subReason: subReason))]
        #expect(try await transport().0.verify(code: "000000", while: { true }) == .rejected)
    }

    @Test func verify_thenAnotherFactor_readsTheWholeMenu() async throws {
        let next = [MfaFactorOffer(id: "push:0", factor: .push, label: "iPhone", reference: 0)]
        client.verifyOtpResults = [.failure(Fix.needs([Fix.challengePush]))]
        #expect(try await transport(menu: { _ in next }).0.verify(code: "123456", while: { true })
            == .anotherFactor(next))
    }

    @Test func verify_withoutAConnection_isANetworkError() async {
        client.verifyOtpResults = [.failure(Fix.network)]
        await #expect(throws: MfaError.network) { try await transport().0.verify(code: "123456", while: { true }) }
    }

    @Test func verify_tooManyWrongCodes_endsTheFlow() async {
        client.verifyOtpResults = [.failure(Fix.terminal("access_denied", description: "too_many_wrong_otp_attempts"))]
        await #expect(throws: MfaError.tooManyAttempts) {
            try await transport().0.verify(code: "000000", while: { true })
        }
    }

    @Test func verify_aPushAnswer_isUnexpected() async {
        client.verifyOtpResults = [.failure(Fix.needs([Fix.verifyOob()], subReason: "authorization_pending"))]
        await #expect(throws: MfaError.unexpected(nil)) {
            try await transport().0.verify(code: "123456", while: { true })
        }
    }

    @Test func verify_isNotSent_whenTheUserLeftWhileItWaited() async {
        await #expect(throws: CancellationError.self) {
            try await transport().0.verify(code: "123456", while: { false })
        }
        #expect(client.calls.isEmpty)
    }
}

/// The authenticator app as a multi-factor step through the whole stack, composed the way `EmbeddedLoginView`
/// composes it: the real login interactor and coordinator, the MFA adapter, the Core, and the factors, against the
/// scripted SDK client.
@Suite
@MainActor
struct EmbeddedMfaTotpEndToEndTests {

    private typealias Fix = EmbeddedAuthFixtures

    private let email = "sudhanshu.vohra@okta.com"
    private let client = StubEmbeddedAuthClient()
    private let store = StubCredentialsDelivery()

    /// Scripts discovery → email → challenge, then answers the email code with `afterTheCode`.
    private func signIn(afterTheCode: EmbeddedAuthError) async -> LoginFlowCoordinator {
        client.authorizeResults = [Fix.needs([Fix.identifyEmail])]
        client.identifyResults = [Fix.needs([Fix.challengeEmail])]
        client.challengeEmailResults = [Fix.needs([Fix.verifyEmail])]
        client.verifyOtpResults = [.failure(afterTheCode)] + client.verifyOtpResults
        let provider = EmbeddedMfaStep(clock: RecordingMfaClock(), bindings: [
            EmbeddedPushBinding(policy: PushPollingPolicy(resendCooldownSeconds: 0)), EmbeddedTotpBinding()
        ])
        let interactor = Auth0EmbeddedAuthInteractor(client: client, credentialsDelivery: store, connection: "email")
        let sut = LoginFlowCoordinator(interactor: interactor, additionalStep: provider)
        await sut.send(.start)
        await sut.send(.submitIdentifier(.email(email)))
        await sut.send(.submitOTP(code: "111111"))
        return sut
    }

    private func eventually(_ condition: () -> Bool) async {
        for _ in 0..<10_000 where !condition() { await Task.yield() }
    }

    private func mfaStep(_ sut: LoginFlowCoordinator) -> MfaStep? {
        (sut.additionalStep as? EmbeddedMfaSession)?.controller.step
    }

    private func codeModel(_ sut: LoginFlowCoordinator) -> TotpChallengeModel? {
        if case let .factor(step)? = mfaStep(sut) { return step.model as? TotpChallengeModel }
        return nil
    }

    private func list(_ sut: LoginFlowCoordinator) -> AuthenticatorListModel? {
        if case let .authenticatorList(model)? = mfaStep(sut) { return model }
        return nil
    }

    /// The codes sent to the server, without the email code that opened the step.
    private var totpCalls: [StubEmbeddedAuthClient.Call] {
        client.calls.filter { if case let .verifyOtp(code, _) = $0 { return code != "111111" } else { return false } }
    }

    @Test func theOnlyFactor_showsTheCodeScreenAtOnce_andTheRightCodeSignsIn() async {
        client.verifyOtpResults = [.success(Credentials(accessToken: "totp"))]

        let sut = await signIn(afterTheCode: Fix.needs([Fix.verifyTOTP]))
        await eventually { codeModel(sut) != nil }
        guard let model = codeModel(sut) else { Issue.record("no code screen"); return }
        #expect(model.canSwitch == false)
        #expect(totpCalls.isEmpty, "nothing is sent before the user types a code")

        model.submit("123456")
        await eventually { sut.step == .authenticated }
        #expect(sut.step == .authenticated)
        #expect(totpCalls == [.verifyOtp(code: "123456", type: .totp)])
        #expect(store.delivered.map(\.accessToken) == ["totp"], "handed to the app once")
    }

    @Test func aWrongCode_staysOnTheCodeScreen_thenTheRightOneSignsIn() async {
        client.verifyOtpResults = [
            .failure(Fix.needs([Fix.verifyTOTP], subReason: "invalid_code")),
            .success(Credentials(accessToken: "totp"))
        ]

        let sut = await signIn(afterTheCode: Fix.needs([Fix.verifyTOTP]))
        await eventually { codeModel(sut) != nil }
        codeModel(sut)?.submit("000000")
        await eventually { codeModel(sut)?.isCodeRejected == true }
        #expect(sut.step == .additionalStep)
        #expect(store.delivered.isEmpty)

        codeModel(sut)?.submit("123456")
        await eventually { sut.step == .authenticated }
        #expect(store.delivered.map(\.accessToken) == ["totp"])
    }

    @Test func pushAndTheApp_areListed_pushFirst_andTheAppCanBePicked() async {
        client.verifyOtpResults = [.success(Credentials(accessToken: "totp"))]

        let sut = await signIn(afterTheCode: Fix.needs([Fix.verifyTOTP, Fix.challengePush]))
        guard let rows = list(sut) else { Issue.record("no list"); return }
        #expect(rows.rows.map(\.id) == ["push:0", "totp"])
        #expect(rows.rows.map(\.subtitle) == ["Push notification", "Enter a code from your authenticator app."])

        rows.select("totp")
        await eventually { codeModel(sut) != nil }
        #expect(codeModel(sut)?.canSwitch == true)
        codeModel(sut)?.submit("123456")
        await eventually { sut.step == .authenticated }
        #expect(store.delivered.map(\.accessToken) == ["totp"])
    }
}
