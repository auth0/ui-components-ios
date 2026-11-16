@testable import Auth0UniversalComponents
import Testing

/// An email or number the server lists a password for first: the password screen, and a code only if the user asks
/// for it.
@Suite
@MainActor
struct LoginFlowCoordinatorPasswordOfferTests {

    private let email = "sarah.doe@atko.email"
    private let phone = "+14233530900"
    private let clock = TestClock()

    private func coordinator(
        identify: Result<IdentifierOutcome, Error>? = .success(.passwordOffered(canSendCode: true)),
        options: [LoginOption] = [.emailOTP(connection: "db"), .phoneOTP(connection: "db")]
    ) -> (LoginFlowCoordinator, ScriptedAuthInteractor) {
        let interactor = ScriptedAuthInteractor(discover: .success(options), startOTP: .success(()),
                                                verifyOTP: .success(.authenticated))
        interactor.identifyResult = identify
        interactor.verifyPasswordResult = .success(.authenticated)
        interactor.startOTPSentTo = "(4**)***-*900"
        return (LoginFlowCoordinator(interactor: interactor, now: { clock.now }), interactor)
    }

    private func atPasswordScreen(
        identifier: LoginIdentifier? = nil,
        identify: Result<IdentifierOutcome, Error>? = .success(.passwordOffered(canSendCode: true))
    ) async -> (LoginFlowCoordinator, ScriptedAuthInteractor) {
        let (sut, interactor) = coordinator(identify: identify)
        await sut.send(.start)
        await sut.send(.submitIdentifier(identifier ?? .email(email)))
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

    @Test func anEmailOfferedAPassword_opensThePasswordScreen_andSendsNoCode() async {
        let (sut, interactor) = await atPasswordScreen()

        #expect(sut.screen == .collectPassword(identifier: .email(email)))
        #expect(requests(interactor) == ["discover", "identify"], "nothing is emailed yet")
        #expect(sut.inputError == nil)
        #expect(!sut.isSubmitting)
    }

    @Test func theCodeIsOffered_onlyWhenTheServerOffersOneToo() async {
        let (both, _) = await atPasswordScreen(identify: .success(.passwordOffered(canSendCode: true)))
        #expect(both.canSendCode)

        let (passwordOnly, _) = await atPasswordScreen(identify: .success(.passwordOffered(canSendCode: false)))
        #expect(passwordOnly.screen == .collectPassword(identifier: .email(email)))
        #expect(!passwordOnly.canSendCode)
    }

    @Test func aNumberOfferedAPassword_opensThePasswordScreenToo() async {
        let (sut, interactor) = await atPasswordScreen(identifier: .phone(phone))
        #expect(sut.screen == .collectPassword(identifier: .phone(phone)))
        #expect(sut.canSendCode)
        #expect(!requests(interactor).contains("startOTP"))
    }

    @Test func anEmailOfferedOnlyACode_getsTheCodeAsBefore() async {
        let (sut, interactor) = await atPasswordScreen(identify: .success(.codeOffered(canUsePassword: false)))

        #expect(sut.screen == .collectOTPCode(identifier: .email(email), sentTo: "(4**)***-*900"))
        #expect(!sut.canSendCode)
        #expect(!sut.canUsePassword)
        #expect(requests(interactor) == ["discover", "identify", "startOTP"])
    }

    @Test func thePasswordSignsIn() async {
        let (sut, interactor) = await atPasswordScreen()

        await sut.send(.submitPassword("correct horse"))

        #expect(sut.step == .authenticated)
        #expect(interactor.receivedRequests.last == .verifyPassword("correct horse"))
    }

    // MARK: A code instead

    @Test func askingForACodeInstead_sendsIt_andOpensCodeEntry() async {
        let (sut, interactor) = await atPasswordScreen()

        await sut.send(.sendCodeInstead)

        #expect(sut.screen == .collectOTPCode(identifier: .email(email), sentTo: "(4**)***-*900"))
        #expect(requests(interactor) == ["discover", "identify", "startOTP"], "the email is not submitted twice")
        #expect(!sut.canSendCode)
    }

    @Test func theCodeThatWasAskedFor_signsIn() async {
        let (sut, interactor) = await atPasswordScreen()
        await sut.send(.sendCodeInstead)

        await sut.send(.submitOTP(code: "123456"))

        #expect(sut.step == .authenticated)
        #expect(interactor.receivedRequests.last == .verifyOTP(code: "123456"))
    }

    @Test func resendingTheCode_sendsACode_ratherThanReturningToThePassword() async {
        let (sut, interactor) = await atPasswordScreen()
        await sut.send(.sendCodeInstead)

        await sut.resendOTP()

        #expect(sut.screen == .collectOTPCode(identifier: .email(email), sentTo: "(4**)***-*900"))
        #expect(requests(interactor) == ["discover", "identify", "startOTP", "startOTP"])
    }

    @Test func aCodeIsOnlyOfferedWhereTheServerOfferedIt() async {
        let (sut, interactor) = await atPasswordScreen(identify: .success(.passwordOffered(canSendCode: false)))

        await sut.send(.sendCodeInstead)

        #expect(sut.screen == .collectPassword(identifier: .email(email)))
        #expect(!requests(interactor).contains("startOTP"))
    }

    @Test func askingForACodeAnywhereElse_doesNothing() async {
        let (sut, interactor) = coordinator()
        await sut.send(.start)
        await sut.send(.sendCodeInstead)
        #expect(sut.step == .collectOTPIdentifier(.email))

        await sut.send(.submitIdentifier(.email(email)))
        #expect(sut.goBack() == .movedBack)
        await sut.send(.sendCodeInstead)
        #expect(sut.step == .collectOTPIdentifier(.email), "the password screen is gone")
        #expect(!requests(interactor).contains("startOTP"))
    }

    @Test func aCodeThatCouldNotBeSent_returnsToTheEmail_withTheReason() async {
        let (sut, interactor) = await atPasswordScreen()
        interactor.startOTPResult = .failure(AuthFailure.codeNotSent)

        await sut.send(.sendCodeInstead)

        #expect(sut.step == .collectOTPIdentifier(.email))
        #expect(sut.inputError == .codeNotSent)
        #expect(!sut.canSendCode, "the email screen offers nothing")
    }

    @Test func aWrongPassword_leavesTheCodeAvailable() async {
        let (sut, interactor) = await atPasswordScreen()
        interactor.verifyPasswordResult = .failure(AuthFailure.invalidPassword)

        await sut.send(.submitPassword("wrong"))
        #expect(sut.screen == .collectPassword(identifier: .email(email)))
        #expect(sut.inputError == .invalidPassword)
        #expect(sut.canSendCode)

        await sut.send(.sendCodeInstead)
        #expect(sut.screen == .collectOTPCode(identifier: .email(email), sentTo: "(4**)***-*900"))
    }

    @Test func aSecondSendWhileOneIsOnItsWay_isIgnored() async {
        let (sut, interactor) = await atPasswordScreen()
        interactor.held = [.startOTP]
        let first = Task { await sut.send(.sendCodeInstead) }
        await interactor.waitUntilHeld(.startOTP)

        await sut.send(.sendCodeInstead)
        interactor.release(.startOTP)
        await first.value

        #expect(requests(interactor).filter { $0 == "startOTP" }.count == 1)
    }

    // MARK: Back

    @Test func backFromThePassword_returnsToTheEmail_whichKeepsWhatWasTyped() async {
        let (sut, _) = await atPasswordScreen()

        #expect(sut.goBack() == .movedBack)

        #expect(sut.step == .collectOTPIdentifier(.email))
        #expect(sut.enteredIdentifier == .email(email))
    }

    @Test func aFailedIdentify_isReportedLikeAFailedCode() async {
        let (sut, _) = await atPasswordScreen(identify: .failure(AuthFailure.tooManyAttempts))
        #expect(sut.step == .collectOTPIdentifier(.email))
        #expect(sut.inputError == .tooManyAttempts)
    }
}
