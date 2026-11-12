@testable import Auth0UniversalComponents
import Auth0
import Foundation
import Testing

/// A recovery code as a multi-factor step through the whole stack, composed the way `EmbeddedLoginView` composes it:
/// the real login interactor and coordinator, the MFA adapter, the Core, and the push and recovery code factors,
/// against the scripted SDK client.
@Suite
@MainActor
struct EmbeddedMfaRecoveryCodeEndToEndTests {

    private typealias Fix = EmbeddedAuthFixtures

    private let client = StubEmbeddedAuthClient()
    private let store = StubCredentialsDelivery()
    private let clock = RecordingMfaClock()

    /// Scripts discovery → email → challenge, then answers the email code with `afterTheCode`.
    private func signIn(afterTheCode: EmbeddedAuthError) async -> LoginFlowCoordinator {
        client.authorizeResults = [Fix.needs([Fix.identifyEmail])]
        client.identifyResults = [Fix.needs([Fix.challengeEmail])]
        client.challengeEmailResults = [Fix.needs([Fix.verifyEmail])]
        client.verifyOtpResults = [.failure(afterTheCode)]
        let provider = EmbeddedMfaStep(clock: clock, bindings: [
            EmbeddedPushBinding(policy: PushPollingPolicy(resendCooldownSeconds: 0)), EmbeddedRecoveryCodeBinding()
        ])
        let interactor = Auth0EmbeddedAuthInteractor(client: client, credentialsDelivery: store, connection: "email")
        let sut = LoginFlowCoordinator(interactor: interactor, additionalStep: provider)
        await sut.send(.start)
        await sut.send(.submitIdentifier(.email("sudhanshu.vohra@okta.com")))
        await sut.send(.submitOTP(code: "111111"))
        return sut
    }

    private func menu(_ entries: [[String: Any]]) -> EmbeddedAuthError { Fix.needs(entries) }

    private func mfaStep(_ sut: LoginFlowCoordinator) -> MfaStep? {
        (sut.additionalStep as? EmbeddedMfaSession)?.controller.step
    }

    private func codeModel(_ sut: LoginFlowCoordinator) -> RecoveryCodeChallengeModel? {
        if case let .factor(step)? = mfaStep(sut) { return step.model as? RecoveryCodeChallengeModel }
        return nil
    }

    private func list(_ sut: LoginFlowCoordinator) -> AuthenticatorListModel? {
        if case let .authenticatorList(model)? = mfaStep(sut) { return model }
        return nil
    }

    /// The requests of the recovery code, not the email code that came before.
    private var recoveryCalls: [StubEmbeddedAuthClient.Call] {
        client.calls.filter {
            switch $0 {
            case .verifyRecoveryCode, .confirmRecoveryCode: return true
            default: return false
            }
        }
    }

    @Test func theCodeIsChecked_thenTheNewOneSaved_thenTheUserIsSignedIn() async {
        client.verifyRecoveryCodeResults = [Fix.needs([Fix.confirmRecoveryCode(newCode: "NEWCODE")])]
        client.confirmRecoveryCodeResults = [.success(Credentials(accessToken: "recovery"))]

        let sut = await signIn(afterTheCode: menu([Fix.verifyRecoveryCode]))
        await eventually { codeModel(sut) != nil }
        #expect(codeModel(sut)?.newCode == nil, "the field, with nothing sent yet")
        #expect(codeModel(sut)?.canSwitch == false)
        #expect(recoveryCalls.isEmpty)

        codeModel(sut)?.submit("  OLDCODE ")
        await eventually { codeModel(sut)?.newCode == "NEWCODE" }
        #expect(recoveryCalls == [.verifyRecoveryCode(code: "OLDCODE")])
        #expect(sut.step == .additionalStep, "not signed in until the new code is confirmed")
        #expect(store.delivered.isEmpty)

        codeModel(sut)?.confirm()
        await eventually { sut.step == .authenticated }
        #expect(recoveryCalls.last == .confirmRecoveryCode)
        #expect(store.delivered.map(\.accessToken) == ["recovery"], "handed to the app once")
    }

    @Test func aWrongCode_staysOnTheField_thenTheRightOneGoesOn() async {
        client.verifyRecoveryCodeResults = [Fix.needs([Fix.verifyRecoveryCode], subReason: "invalid_code"),
                                            Fix.needs([Fix.confirmRecoveryCode(newCode: "NEWCODE")])]
        let sut = await signIn(afterTheCode: menu([Fix.verifyRecoveryCode]))
        await eventually { codeModel(sut) != nil }

        codeModel(sut)?.submit("BAD")
        await eventually { codeModel(sut)?.isCodeRejected == true }
        #expect(sut.step == .additionalStep)
        #expect(codeModel(sut)?.newCode == nil)

        codeModel(sut)?.submit("OLDCODE")
        await eventually { codeModel(sut)?.newCode == "NEWCODE" }
        #expect(codeModel(sut)?.isCodeRejected == false)
    }

    @Test func aDroppedConnectionWhileConfirming_keepsTheNewCodeOnScreen() async {
        client.verifyRecoveryCodeResults = [Fix.needs([Fix.confirmRecoveryCode(newCode: "NEWCODE")])]
        client.confirmRecoveryCodeResults = [.failure(Fix.network), .success(Credentials(accessToken: "recovery"))]
        let sut = await signIn(afterTheCode: menu([Fix.verifyRecoveryCode]))
        await eventually { codeModel(sut) != nil }
        codeModel(sut)?.submit("OLDCODE")
        await eventually { codeModel(sut)?.newCode != nil }

        codeModel(sut)?.confirm()
        await eventually { codeModel(sut)?.requestError == .network }
        #expect(codeModel(sut)?.newCode == "NEWCODE", "the old code no longer works: this one must stay")
        #expect(sut.step == .additionalStep)

        codeModel(sut)?.confirm()
        await eventually { sut.step == .authenticated }
        #expect(store.delivered.map(\.accessToken) == ["recovery"])
    }

    /// Listed last, and picked from the list; "Verify another way" goes back to it.
    @Test func withPush_itIsListedLast_andCanBePickedAndLeft() async {
        let sut = await signIn(afterTheCode: menu([Fix.verifyRecoveryCode, Fix.challengePush]))
        guard let rows = list(sut) else { Issue.record("no list"); return }
        #expect(rows.rows.map(\.id) == ["push:0", "recovery_code:0"])
        #expect(rows.rows.map(\.title).last == "Recovery code")
        #expect(recoveryCalls.isEmpty, "nothing is sent until the user types a code")

        rows.select("recovery_code:0")
        await eventually { codeModel(sut) != nil }
        #expect(codeModel(sut)?.canSwitch == true)
        codeModel(sut)?.switchFactor()
        await eventually { list(sut) != nil }
        #expect(list(sut)?.rows.count == 2)
    }

    @Test func tooManyAttempts_endsWithTheErrorScreen() async {
        client.verifyRecoveryCodeResults = [Fix.terminal("access_denied", description: "too_many_wrong_otp_attempts")]
        let sut = await signIn(afterTheCode: menu([Fix.verifyRecoveryCode]))
        await eventually { codeModel(sut) != nil }
        codeModel(sut)?.submit("BAD")
        await eventually { if case .error = mfaStep(sut) { return true } else { return false } }
        guard case let .error(model)? = mfaStep(sut) else { Issue.record("no error screen"); return }
        #expect(model.error == .tooManyAttempts)
        #expect(store.delivered.isEmpty)
    }

    /// Back on the field cancels MFA: a fresh sign-in, and nothing reaches the app.
    @Test func back_cancelsTheFactor_andReturnsToTheFirstScreen() async {
        let sut = await signIn(afterTheCode: menu([Fix.verifyRecoveryCode]))
        await eventually { codeModel(sut) != nil }
        sut.goBack()
        await eventually { sut.step == .collectOTPIdentifier(.email) }
        #expect(sut.step == .collectOTPIdentifier(.email))
        #expect(store.delivered.isEmpty)
    }
}
