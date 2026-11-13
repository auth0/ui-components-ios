@testable import Auth0UniversalComponents
import Foundation
import Testing

/// An email or number the server lists a code for first: the code goes out at once, and a password, when the server
/// also offers one, is the alternative on the code screen.
@Suite
@MainActor
struct LoginFlowCoordinatorCodeOfferTests {

    private let email = "sarah.doe@atko.email"
    private let sentTo = "(4**)***-*900"
    private let clock = TestClock()

    private func coordinator(
        identify: Result<IdentifierOutcome, Error>? = .success(.codeOffered(canUsePassword: true))
    ) -> (LoginFlowCoordinator, ScriptedAuthInteractor) {
        let interactor = ScriptedAuthInteractor(
            discover: .success([.emailOTP(connection: "db"), .phoneOTP(connection: "db")]),
            startOTP: .success(()), verifyOTP: .success(.authenticated))
        interactor.identifyResult = identify
        interactor.verifyPasswordResult = .success(.authenticated)
        interactor.startOTPSentTo = sentTo
        return (LoginFlowCoordinator(interactor: interactor, now: { clock.now }), interactor)
    }

    private func atCodeScreen(
        identify: Result<IdentifierOutcome, Error>? = .success(.codeOffered(canUsePassword: true))
    ) async -> (LoginFlowCoordinator, ScriptedAuthInteractor) {
        let (sut, interactor) = coordinator(identify: identify)
        await sut.send(.start)
        await sut.send(.submitIdentifier(.email(email)))
        return (sut, interactor)
    }

    private func requests(_ interactor: ScriptedAuthInteractor) -> [String] {
        interactor.receivedRequests.map {
            switch $0 {
            case .discover: return "discover"
            case .identify: return "identify"
            case .startOTP: return "startOTP"
            case .verifyOTP: return "verifyOTP"
            case .verifyPassword: return "verifyPassword"
            }
        }
    }

    // MARK: The offer

    @Test func aCodeListedFirst_isSentAtOnce_withThePasswordAsTheAlternative() async {
        let (sut, interactor) = await atCodeScreen()

        #expect(sut.screen == .collectOTPCode(identifier: .email(email), sentTo: sentTo))
        #expect(sut.canUsePassword)
        #expect(!sut.canSendCode)
        #expect(requests(interactor) == ["discover", "identify", "startOTP"])
    }

    @Test func aCodeWithNoPasswordBesideIt_offersNoAlternative() async {
        let (sut, _) = await atCodeScreen(identify: .success(.codeOffered(canUsePassword: false)))

        #expect(sut.screen == .collectOTPCode(identifier: .email(email), sentTo: sentTo))
        #expect(!sut.canUsePassword)
    }

    @Test func theCodeSignsIn() async {
        let (sut, interactor) = await atCodeScreen()

        await sut.send(.submitOTP(code: "123456"))

        #expect(sut.step == .authenticated)
        #expect(interactor.receivedRequests.last == .verifyOTP(code: "123456"))
    }

    // MARK: A password instead

    @Test func askingForThePasswordInstead_identifiesAgain_andOpensThePasswordScreen() async {
        let (sut, interactor) = await atCodeScreen()

        await sut.send(.usePasswordInstead)

        #expect(sut.screen == .collectPassword(identifier: .email(email)))
        #expect(sut.canSendCode, "the code stays one tap away")
        #expect(!sut.canUsePassword)
        #expect(requests(interactor) == ["discover", "identify", "startOTP", "identify"],
                "the code's sign-in may have ended, so the server is asked again")
    }

    @Test func thePasswordThatWasAskedFor_signsIn() async {
        let (sut, interactor) = await atCodeScreen()
        await sut.send(.usePasswordInstead)

        await sut.send(.submitPassword("correct horse"))

        #expect(sut.step == .authenticated)
        #expect(interactor.receivedRequests.last == .verifyPassword("correct horse"))
    }

    @Test func thePasswordScreen_canGoBackToTheCode_onceTheWaitIsOver_andTheCodeScreenToThePasswordAgain() async {
        let (sut, interactor) = await atCodeScreen()
        await sut.send(.usePasswordInstead)

        clock.waitOutTheCodeCooldown()
        await sut.send(.sendCodeInstead)
        #expect(sut.screen == .collectOTPCode(identifier: .email(email), sentTo: sentTo))
        #expect(sut.canUsePassword, "the password it came from is still offered")

        await sut.send(.usePasswordInstead)
        #expect(sut.screen == .collectPassword(identifier: .email(email)))
        #expect(requests(interactor) == [
            "discover", "identify", "startOTP", "identify", "startOTP", "identify"
        ])
    }

    @Test func aCodeAskedForAgainTooSoon_isIgnored_untilTheWaitIsOver() async {
        let (sut, interactor) = await atCodeScreen()
        await sut.send(.usePasswordInstead)

        await sut.send(.sendCodeInstead)
        #expect(sut.screen == .collectPassword(identifier: .email(email)), "still waiting")
        #expect(!requests(interactor).suffix(1).contains("startOTP"))
        #expect(sut.codeAvailableAt(for: .email(email)) == clock.now.addingTimeInterval(60))

        clock.advance(by: 59)
        await sut.send(.sendCodeInstead)
        #expect(sut.screen == .collectPassword(identifier: .email(email)), "a second short")

        clock.advance(by: 1)
        await sut.send(.sendCodeInstead)
        #expect(sut.screen == .collectOTPCode(identifier: .email(email), sentTo: sentTo))
    }

    @Test func theWait_isForTheSomeoneACodeWasSentTo() async {
        let (sut, _) = await atCodeScreen()
        #expect(sut.codeAvailableAt(for: .email(email)) != nil)
        #expect(sut.codeAvailableAt(for: .email("someone.else@atko.email")) == nil)
        #expect(sut.codeAvailableAt(for: nil) == nil)
    }

    @Test func aPasswordThatTheServerNoLongerOffers_returnsToTheEmail_withTheReason() async {
        let (sut, interactor) = await atCodeScreen()
        interactor.identifyResult = .success(.codeOffered(canUsePassword: false))

        await sut.send(.usePasswordInstead)

        #expect(sut.step == .collectOTPIdentifier(.email))
        #expect(sut.inputError == .passwordNotAvailable)
    }

    @Test func aPasswordTheServerOffersWithNoCodeBesideIt_hasNoCodeToSwitchBackTo() async {
        let (sut, interactor) = await atCodeScreen()
        interactor.identifyResult = .success(.passwordOffered(canSendCode: false))

        await sut.send(.usePasswordInstead)

        #expect(sut.screen == .collectPassword(identifier: .email(email)))
        #expect(!sut.canSendCode)
    }

    @Test func aPasswordInstead_whereNoneWasOffered_doesNothing() async {
        let (sut, interactor) = await atCodeScreen(identify: .success(.codeOffered(canUsePassword: false)))

        await sut.send(.usePasswordInstead)

        #expect(sut.screen == .collectOTPCode(identifier: .email(email), sentTo: sentTo))
        #expect(requests(interactor) == ["discover", "identify", "startOTP"])
    }

    @Test func askingForAPasswordAnywhereElse_doesNothing() async {
        let (sut, interactor) = coordinator()
        await sut.send(.start)
        await sut.send(.usePasswordInstead)
        #expect(sut.step == .collectOTPIdentifier(.email))
        #expect(requests(interactor) == ["discover"])
    }

    @Test func aSecondRequestWhileOneIsOnItsWay_isIgnored() async {
        let (sut, interactor) = await atCodeScreen()
        interactor.held = [.identify]
        let first = Task { await sut.send(.usePasswordInstead) }
        await interactor.waitUntilHeld(.identify)

        await sut.send(.usePasswordInstead)
        interactor.release(.identify)
        await first.value

        #expect(requests(interactor).filter { $0 == "identify" }.count == 2, "one at submit, one for the password")
    }

    // MARK: Resend

    @Test func resendingTheCode_staysOnTheCode_andKeepsThePasswordOffered() async {
        let (sut, interactor) = await atCodeScreen()

        await sut.resendOTP()

        #expect(sut.screen == .collectOTPCode(identifier: .email(email), sentTo: sentTo))
        #expect(sut.canUsePassword)
        #expect(requests(interactor) == ["discover", "identify", "startOTP", "startOTP"],
                "a resend asks for the code again, not for who the user is")
    }

    @Test func aCodeThatCouldNotBeSent_returnsToTheEmail_withTheReason() async {
        let (sut, interactor) = coordinator()
        interactor.startOTPResult = .failure(AuthFailure.codeNotSent)
        await sut.send(.start)

        await sut.send(.submitIdentifier(.email(email)))

        #expect(sut.step == .collectOTPIdentifier(.email))
        #expect(sut.inputError == .codeNotSent)
        #expect(!sut.canUsePassword)
    }

    // MARK: Back

    @Test func backFromThePasswordThatWasAskedFor_returnsToTheEmail() async {
        let (sut, _) = await atCodeScreen()
        await sut.send(.usePasswordInstead)

        #expect(sut.goBack() == .movedBack)

        #expect(sut.step == .collectOTPIdentifier(.email))
        #expect(sut.enteredIdentifier == .email(email))
    }
}
