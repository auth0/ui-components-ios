@testable import Auth0UniversalComponents
// swiftlint:disable file_length
import Auth0
import Foundation
import SwiftUI
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

/// The factor's own pieces: its words, its standard screen, and the typed shortcut that replaces that screen.
@Suite
@MainActor
struct TotpFactorTests {

    @Test func aCustomScreen_replacesTheFactorsScreen_throughItsTypedShortcut() {
        let screens = MfaScreens(totpChallenge: .custom { (model: TotpChallengeModel) in Text("\(model.codeLength)") })
        #expect(screens.factorViews[.totp] != nil)
        #expect(screens.factorViews[.sms] == nil, "only the authenticator screen is replaced")
        #expect(screens.factorViews[.totp]?(TotpChallengeModel()) != nil)
        #expect(screens.factorViews[.totp]?(PhoneCodeChallengeModel(destination: "x")) == nil)
    }

    @Test func theStandardSlot_replacesNothing() {
        #expect(MfaScreens(totpChallenge: .standard).factorViews[.totp] == nil)
    }

    @Test func theStandardScreen_isOnlyForTheFactorsOwnModel() {
        let sut = TotpFactor(transport: ScriptedTotpTransport())
        #expect(sut.standardView(for: TotpChallengeModel(), messages: .default) != nil)
        #expect(sut.standardView(for: PhoneCodeChallengeModel(destination: "x"), messages: .default) == nil)
    }

    @Test func theDefaultWords_areTheDesigns() {
        let sut = MfaMessages.default.totpChallenge
        #expect(sut.row.title == "Authenticator app")
        #expect(sut.row.description == "Enter a code from your authenticator app.")
        #expect(sut.title == "Enter the 6-digit code")
        #expect(sut.subtitle == "From your authenticator app")
        #expect(sut.fieldLabel == "One-Time Passcode")
        #expect(sut.verify == "Continue")
        #expect(sut.invalidCode == "Invalid Code. Please double check the code in your authenticator app.")
        #expect(sut.noConnection == "No connection. Check your connection and try again.")
        #expect(sut.verifyAnotherWay == "Verify another way")
    }

    @Test func theWords_canBeChangedOneLeafAtATime() {
        let changed = MfaMessages.default.with { $0.totpChallenge.subtitle = "From my app" }
        #expect(changed.totpChallenge.subtitle == "From my app")
        #expect(changed.totpChallenge.title == "Enter the 6-digit code", "the rest keeps its default")
        #expect(MfaMessages.default.totpChallenge.subtitle == "From your authenticator app")
    }
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

    /// A text or call sent earlier is no longer the code the server waits for once a code was checked, whether it was
    /// right or wrong, so the gate must stop reporting it as the last challenge.
    @Test func verify_isRecordedOnTheGate_soAnEarlierChallengeIsNoLongerTheLastOne() async throws {
        let gate = EmbeddedRequestGate()
        try await gate.run(challenging: "sms:0") {}
        #expect(gate.lastChallenge == "sms:0")

        client.verifyOtpResults = [.failure(Fix.needs([Fix.verifyTOTP], subReason: "invalid_code"))]
        let sut = EmbeddedTotpTransport(client: client, stager: EmbeddedMfaStager(delivery: store), gate: gate,
                                        menu: { _ in [] })
        _ = try await sut.verify(code: "000000", while: { true })
        #expect(gate.lastChallenge == EmbeddedTotpBinding.offerID, "a wrong code moves the session on too")
    }

    @Test func verify_thatIsNotSent_leavesTheLastChallengeAlone() async {
        let gate = EmbeddedRequestGate()
        try? await gate.run(challenging: "sms:0") {}
        let sut = EmbeddedTotpTransport(client: client, stager: EmbeddedMfaStager(delivery: store), gate: gate,
                                        menu: { _ in [] })
        _ = try? await sut.verify(code: "123456", while: { false })
        #expect(gate.lastChallenge == "sms:0", "nothing went out, so nothing replaced it")
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
    private let clock = RecordingMfaClock()

    /// Scripts discovery → email → challenge, then answers the email code with `afterTheCode`. Push and the app are
    /// plugged in, and a text message too when `phoneWait` is given (its resend wait, in seconds).
    private func signIn(afterTheCode: EmbeddedAuthError, phoneWait: Int? = nil) async -> LoginFlowCoordinator {
        client.authorizeResults = [Fix.needs([Fix.identifyEmail])]
        client.identifyResults = [Fix.needs([Fix.challengeEmail])]
        client.challengeEmailResults = [Fix.needs([Fix.verifyEmail])]
        client.verifyOtpResults = [.failure(afterTheCode)] + client.verifyOtpResults
        var bindings: [EmbeddedFactorBinding] = [
            EmbeddedPushBinding(policy: PushPollingPolicy(resendCooldownSeconds: 0)), EmbeddedTotpBinding()
        ]
        if let phoneWait {
            bindings.append(EmbeddedPhoneCodeBinding(delivery: .text,
                                                     policy: PhoneCodePolicy(resendCooldownSeconds: phoneWait)))
        }
        let provider = EmbeddedMfaStep(clock: clock, bindings: bindings)
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

    private func phoneModel(_ sut: LoginFlowCoordinator) -> PhoneCodeChallengeModel? {
        if case let .factor(step)? = mfaStep(sut) { return step.model as? PhoneCodeChallengeModel }
        return nil
    }

    private func pushModel(_ sut: LoginFlowCoordinator) -> PushChallengeModel? {
        if case let .factor(step)? = mfaStep(sut) { return step.model as? PushChallengeModel }
        return nil
    }

    /// Waits for `condition` and, if it never comes true, names the step: a failure then points at the step that
    /// stalled, not at what was off two steps later.
    private func reach(_ step: String, sourceLocation: SourceLocation = #_sourceLocation,
                       _ condition: () -> Bool) async {
        await eventually(condition)
        #expect(condition(), "never reached: \(step)", sourceLocation: sourceLocation)
    }

    /// The texts sent to a phone.
    private var phoneSends: [StubEmbeddedAuthClient.Call] {
        client.calls.filter { if case .challengePhone = $0 { return true } else { return false } }
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

    // MARK: Failures

    /// Too many wrong codes locks the sign-in: that ends the flow, on the engine's error screen.
    @Test func tooManyWrongCodes_endsWithTheErrorScreen() async {
        client.verifyOtpResults = [.failure(Fix.terminal("access_denied", description: "too_many_wrong_otp_attempts"))]

        let sut = await signIn(afterTheCode: Fix.needs([Fix.verifyTOTP]))
        await reach("the code screen") { codeModel(sut) != nil }
        codeModel(sut)?.submit("000000")
        await reach("the error screen") { if case .error = mfaStep(sut) { return true } else { return false } }
        guard case let .error(model)? = mfaStep(sut) else { Issue.record("no error screen"); return }
        #expect(model.error == .tooManyAttempts)
        #expect(store.delivered.isEmpty)
    }

    /// The code never reached the server, so the screen stays and the same code can be sent again.
    @Test func aDroppedConnection_keepsTheCodeScreen_andTheSameCodeCanBeSentAgain() async {
        client.verifyOtpResults = [.failure(Fix.network), .success(Credentials(accessToken: "totp"))]

        let sut = await signIn(afterTheCode: Fix.needs([Fix.verifyTOTP]))
        await reach("the code screen") { codeModel(sut) != nil }
        codeModel(sut)?.submit("123456")
        await reach("the connection message") { codeModel(sut)?.requestError == .network }
        #expect(sut.step == .additionalStep, "no error screen")
        #expect(codeModel(sut)?.isVerifying == false)

        codeModel(sut)?.submit("123456")
        await reach("the sign-in completing") { sut.step == .authenticated }
        #expect(totpCalls == [.verifyOtp(code: "123456", type: .totp), .verifyOtp(code: "123456", type: .totp)])
        #expect(store.delivered.map(\.accessToken) == ["totp"])
    }

    // MARK: A round that ends with a code

    /// The policy needs more than the app's code: the code is accepted without signing the user in, and the next
    /// round's factor starts.
    @Test func aRightCode_thatAsksForAnotherFactor_startsTheNextRound() async {
        clock.suspends = true
        client.verifyOtpResults = [.failure(Fix.needs([Fix.challengePush]))]
        client.challengePushResults = [Fix.needs([Fix.verifyOob()])]

        let sut = await signIn(afterTheCode: Fix.needs([Fix.verifyTOTP]))
        await reach("the code screen") { codeModel(sut) != nil }
        codeModel(sut)?.submit("123456")
        await reach("the push screen of the next round") { pushModel(sut) != nil }
        #expect(sut.step == .additionalStep, "not signed in yet")
        #expect(store.delivered.isEmpty)
        #expect(client.calls.contains(.challengePush(index: 0)))
        if case let .factor(step)? = mfaStep(sut) { #expect(step.round == 2) }
    }

    // MARK: Coming back to a phone after a code was checked

    /// A text goes out, the user picks the app instead and its code is accepted, and the policy asks for the phone in
    /// the next round. Checking a code moved the sign-in's session on, so the earlier text can't be the one the server
    /// waits for: a new one goes out, with a wait of its own, though the first is still inside its 60 seconds.
    @Test func smsThenTheApp_thenSmsAgain_textsAgain() async {
        clock.suspends = true
        client.challengePhoneResults = [Fix.needs([Fix.verifySMS, Fix.challengePhone()]),
                                        Fix.needs([Fix.verifySMS, Fix.challengePhone()])]
        client.verifyOtpResults = [.failure(Fix.needs([Fix.challengePhone(), Fix.verifySMS]))]

        let sut = await signIn(afterTheCode: Fix.needs([Fix.challengePhone(), Fix.verifyTOTP]), phoneWait: 60)
        await reach("the factor list") { list(sut) != nil }
        list(sut)?.select("sms:0")
        await reach("the text's code screen") { phoneModel(sut) != nil }
        phoneModel(sut)?.switchFactor()
        await reach("the factor list again") { list(sut) != nil }
        list(sut)?.select("totp")
        await reach("the app's code screen") { codeModel(sut) != nil }
        codeModel(sut)?.submit("123456")

        await reach("the text of the next round, sent anew") { phoneSends.count == 2 && phoneModel(sut) != nil }
        #expect(phoneSends.count == 2)
        #expect((phoneModel(sut)?.resendAvailableIn ?? 0) > 0, "with a wait of its own")
    }

    /// A wrong code moves the session on too, so coming back to the text sends a new one.
    @Test func smsThenAWrongCodeFromTheApp_thenSmsAgain_textsAgain() async {
        clock.suspends = true
        client.challengePhoneResults = [Fix.needs([Fix.verifySMS, Fix.challengePhone()]),
                                        Fix.needs([Fix.verifySMS, Fix.challengePhone()])]
        client.verifyOtpResults = [.failure(Fix.needs([Fix.verifyTOTP], subReason: "invalid_code"))]

        let sut = await signIn(afterTheCode: Fix.needs([Fix.challengePhone(), Fix.verifyTOTP]), phoneWait: 60)
        await reach("the factor list") { list(sut) != nil }
        list(sut)?.select("sms:0")
        await reach("the text's code screen") { phoneModel(sut) != nil }
        phoneModel(sut)?.switchFactor()
        await reach("the factor list again") { list(sut) != nil }
        list(sut)?.select("totp")
        await reach("the app's code screen") { codeModel(sut) != nil }
        codeModel(sut)?.submit("000000")
        await reach("the rejected code") { codeModel(sut)?.isCodeRejected == true }
        codeModel(sut)?.switchFactor()
        await reach("the factor list a third time") { list(sut) != nil }

        list(sut)?.select("sms:0")
        await reach("a second text, with a wait of its own") {
            phoneSends.count == 2 && (phoneModel(sut)?.resendAvailableIn ?? 0) > 0
        }
        #expect(phoneSends.count == 2)
    }
}
