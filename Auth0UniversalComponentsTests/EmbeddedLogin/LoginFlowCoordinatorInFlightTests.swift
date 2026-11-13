@testable import Auth0UniversalComponents
import Testing

/// While a request is on its way the coordinator is `.loading` and `displayedStep` keeps the screen on display, with
/// the alternative it offers, so Continue, OR and the other button don't jump. When the answer arrives, the screen it
/// leads to carries its own alternative.
@Suite
@MainActor
struct LoginFlowCoordinatorInFlightTests {

    private let email = "sarah.doe@atko.email"
    private let sentTo = "(4**)***-*900"
    private let clock = TestClock()

    /// Signed in as far as the screen that `outcome` leads to.
    private func coordinator(_ outcome: IdentifierOutcome) async -> (LoginFlowCoordinator, ScriptedAuthInteractor) {
        let interactor = ScriptedAuthInteractor(
            discover: .success([.emailOTP(connection: "db"), .phoneOTP(connection: "db")]),
            startOTP: .success(()), verifyOTP: .success(.authenticated))
        interactor.identifyResult = .success(outcome)
        interactor.verifyPasswordResult = .success(.authenticated)
        interactor.startOTPSentTo = sentTo
        let sut = LoginFlowCoordinator(interactor: interactor, now: { clock.now })
        await sut.send(.start)
        await sut.send(.submitIdentifier(.email(email)))
        return (sut, interactor)
    }

    /// Starts `action`, holds `call` in flight, and returns what the host shows then.
    private func shown(whileHolding call: ScriptedAuthInteractor.Call, on sut: LoginFlowCoordinator,
                       _ interactor: ScriptedAuthInteractor,
                       during action: @escaping @MainActor () async -> Void) async -> LoginStep {
        interactor.held = [call]
        let task = Task { await action() }
        await interactor.waitUntilHeld(call)
        let displayed = sut.displayedStep
        #expect(sut.step == .loading)
        #expect(sut.isSubmitting)
        interactor.release(call)
        await task.value
        return displayed
    }

    @Test func whileTheCodeIsBeingSent_thePasswordScreenStaysWithItsCodeButton() async {
        let (sut, interactor) = await coordinator(.passwordOffered(canSendCode: true))

        let displayed = await shown(whileHolding: .startOTP, on: sut, interactor) {
            await sut.send(.sendCodeInstead)
        }

        #expect(displayed == .collectPassword(identifier: .email(email), canSendCode: true))
        #expect(sut.canUsePassword, "and the code screen it leads to offers the way back")
    }

    @Test func whileAPasswordIsBeingChecked_theCodeButtonStaysOnTheScreen() async {
        let (sut, interactor) = await coordinator(.passwordOffered(canSendCode: true))

        let displayed = await shown(whileHolding: .verifyPassword, on: sut, interactor) {
            await sut.send(.submitPassword("correct horse"))
        }

        #expect(displayed == .collectPassword(identifier: .email(email), canSendCode: true))
        #expect(sut.step == .authenticated)
    }

    @Test func whileThePasswordIsBeingAskedFor_theCodeScreenStaysWithItsPasswordButton() async {
        let (sut, interactor) = await coordinator(.codeOffered(canUsePassword: true))

        let displayed = await shown(whileHolding: .identify, on: sut, interactor) {
            await sut.send(.usePasswordInstead)
        }

        #expect(displayed == .collectOTPCode(identifier: .email(email), sentTo: sentTo, canUsePassword: true))
        #expect(sut.canSendCode, "and the password screen it leads to offers the way back")
    }

    @Test func whileACodeIsBeingResent_thePasswordButtonStaysOnTheScreen() async {
        let (sut, interactor) = await coordinator(.codeOffered(canUsePassword: true))

        let displayed = await shown(whileHolding: .startOTP, on: sut, interactor) { await sut.resendOTP() }

        #expect(displayed == .collectOTPCode(identifier: .email(email), sentTo: sentTo, canUsePassword: true))
    }

    @Test func whileACodeIsBeingChecked_thePasswordButtonStaysOnTheScreen() async {
        let (sut, interactor) = await coordinator(.codeOffered(canUsePassword: true))

        let displayed = await shown(whileHolding: .verifyOTP, on: sut, interactor) {
            await sut.send(.submitOTP(code: "123456"))
        }

        #expect(displayed == .collectOTPCode(identifier: .email(email), sentTo: sentTo, canUsePassword: true))
    }

    @Test func aResend_keepsThePasswordOffered_becauseTheServerOfferedIt() async {
        let (sut, _) = await coordinator(.codeOffered(canUsePassword: true))

        await sut.resendOTP()

        #expect(sut.canUsePassword)
    }

    @Test func aResend_offersNoPassword_whereTheServerOfferedNone() async {
        let (sut, _) = await coordinator(.codeOffered(canUsePassword: false))

        await sut.resendOTP()

        #expect(!sut.canUsePassword)
    }

    @Test func afterTheRequest_theNewScreenIsTheOneOnDisplay() async {
        let (sut, _) = await coordinator(.passwordOffered(canSendCode: true))

        await sut.send(.sendCodeInstead)

        #expect(sut.displayedStep == sut.step)
    }

    // MARK: A rate limit stays where it was

    @Test func aRateLimitOnANewCode_keepsThePasswordScreen_withItsCodeButton() async {
        let (sut, interactor) = await coordinator(.passwordOffered(canSendCode: true))
        interactor.startOTPResult = .failure(AuthFailure.tooManyAttempts)

        await sut.send(.sendCodeInstead)

        #expect(sut.step == .collectPassword(identifier: .email(email), canSendCode: true))
        #expect(sut.inputError == .tooManyAttempts)
    }

    @Test func aRateLimitOnAResend_keepsTheCodeScreen_withItsPasswordButton() async {
        let (sut, interactor) = await coordinator(.codeOffered(canUsePassword: true))
        interactor.startOTPResult = .failure(AuthFailure.tooManyAttempts)

        await sut.resendOTP()

        #expect(sut.step == .collectOTPCode(identifier: .email(email), sentTo: sentTo, canUsePassword: true))
        #expect(sut.inputError == .tooManyAttempts)
    }

    @Test func aRateLimitOnTheEmail_staysOnTheEmailScreen() async {
        let interactor = ScriptedAuthInteractor(discover: .success([.emailOTP(connection: "db")]))
        interactor.identifyResult = .failure(AuthFailure.tooManyAttempts)
        let sut = LoginFlowCoordinator(interactor: interactor)
        await sut.send(.start)

        await sut.send(.submitIdentifier(.email(email)))

        #expect(sut.step == .collectOTPIdentifier(.email))
        #expect(sut.inputError == .tooManyAttempts)
    }

    @Test func aCodeThatCouldNotBeSent_stillSendsTheUserBackToTheEmail() async {
        let (sut, interactor) = await coordinator(.codeOffered(canUsePassword: true))
        interactor.startOTPResult = .failure(AuthFailure.codeNotSent)

        await sut.resendOTP()

        #expect(sut.step == .collectOTPIdentifier(.email))
    }

    @Test func afterAFailedRequest_theEmailScreenOffersNothing() async {
        let (sut, interactor) = await coordinator(.passwordOffered(canSendCode: true))
        interactor.startOTPResult = .failure(AuthFailure.codeNotSent)

        await sut.send(.sendCodeInstead)

        #expect(sut.step == .collectOTPIdentifier(.email))
        #expect(!sut.canSendCode)
        #expect(!sut.canUsePassword)
    }
}
