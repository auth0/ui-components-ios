@testable import Auth0UniversalComponents
import Testing

/// Sign-in with a username and password, and the first screen when it is one of several ways.
@Suite
@MainActor
struct LoginFlowCoordinatorPasswordTests {

    private let username = "sarah.doe"
    private let password = "correct horse"
    private let provider = ScriptedAdditionalStepProvider()

    private func coordinator(
        offering options: [LoginOption] = [.password(connection: "db")],
        identify: Result<IdentifierOutcome, Error>? = .success(.passwordOffered(canSendCode: false)),
        verifyPassword: Result<AuthProgress, Error>? = .success(.authenticated),
        additionalStep: AdditionalStepProviding? = nil
    ) -> (LoginFlowCoordinator, ScriptedAuthInteractor) {
        let interactor = ScriptedAuthInteractor(discover: .success(options))
        interactor.identifyResult = identify
        interactor.verifyPasswordResult = verifyPassword
        return (LoginFlowCoordinator(interactor: interactor, additionalStep: additionalStep), interactor)
    }

    /// Discovery → username, left on the password screen.
    private func atPassword(
        verifyPassword: Result<AuthProgress, Error>? = .success(.authenticated),
        additionalStep: AdditionalStepProviding? = nil
    ) async -> (LoginFlowCoordinator, ScriptedAuthInteractor) {
        let (sut, interactor) = coordinator(verifyPassword: verifyPassword, additionalStep: additionalStep)
        await sut.send(.start)
        await sut.send(.submitIdentifier(.username(username)))
        return (sut, interactor)
    }

    // MARK: The first screen

    @Test func aPasswordOnlyTenant_startsOnTheUsernameScreen() async {
        let (sut, _) = coordinator()
        await sut.send(.start)
        #expect(sut.channels == [.password])
        #expect(sut.step == .collectOTPIdentifier(.password))
    }

    @Test func theTenantsOrderDecides_andPasswordIsOneOfTheOthers() async {
        let (sut, _) = coordinator(offering: [.emailOTP(connection: "c"), .password(connection: "c")])
        await sut.send(.start)
        #expect(sut.channels == [.email, .password])
        #expect(sut.step == .collectOTPIdentifier(.email))

        await sut.send(.chooseChannel(.password))
        #expect(sut.step == .collectOTPIdentifier(.password))
        #expect(sut.goBack() == .movedBack)
        #expect(sut.step == .collectOTPIdentifier(.email))
    }

    @Test func passwordFirst_listsTheCodeWaysUnderIt() async {
        let (sut, _) = coordinator(offering: [.password(connection: "c"), .emailOTP(connection: "c")])
        await sut.send(.start)
        #expect(sut.step == .collectOTPIdentifier(.password))
        await sut.send(.chooseChannel(.email))
        #expect(sut.step == .collectOTPIdentifier(.email))
    }

    // MARK: The username

    @Test func theUsername_isSubmittedToTheConnection_andTheServerAsksForThePassword() async {
        let (sut, interactor) = await atPassword()
        #expect(sut.screen == .collectPassword(identifier: .username(username)))
        #expect(interactor.receivedRequests.last == .identify(connection: "db", identifier: .username(username)))
        #expect(sut.enteredIdentifier == .username(username))
        #expect(sut.inputError == nil)
        #expect(!sut.isSubmitting)
    }

    @Test func aUsernameWithNoPasswordStep_staysOnTheUsernameScreen_withAnInlineError() async {
        let (sut, _) = coordinator(identify: .failure(AuthFailure.invalidPassword))
        await sut.send(.start)
        await sut.send(.submitIdentifier(.username(username)))
        #expect(sut.step == .collectOTPIdentifier(.password))
        #expect(sut.inputError == .invalidPassword)
        #expect(sut.enteredIdentifier == .username(username), "kept, so the screen shows what was typed")
    }

    @Test func aFailedUsernameStep_endsOnAnError_andRetryReturnsToTheUsernameScreen() async {
        let down = ScriptedAuthInteractor.ScriptedAuthError.scripted(message: "down")
        let (sut, _) = coordinator(identify: .failure(down))
        await sut.send(.start)
        await sut.send(.submitIdentifier(.username(username)))
        #expect(sut.step == .failed(message: "down"))

        await sut.send(.retry)
        #expect(sut.step == .collectOTPIdentifier(.password))
    }

    @Test func aSecondUsernameSubmit_whileOneIsOnItsWay_isIgnored() async {
        let (sut, interactor) = coordinator()
        interactor.held = [.identify]
        await sut.send(.start)
        let first = Task { await sut.send(.submitIdentifier(.username(username))) }
        await interactor.waitUntilHeld(.identify)

        await sut.send(.submitIdentifier(.username("someone.else")))
        interactor.release(.identify)
        await first.value
        #expect(interactor.receivedRequests.filter {
            if case .identify = $0 { return true } else { return false }
        }.count == 1)
    }

    // MARK: The password

    @Test func theRightPassword_signsIn() async {
        let (sut, interactor) = await atPassword()
        await sut.send(.submitPassword(password))
        #expect(sut.step == .authenticated)
        #expect(interactor.receivedRequests.last == .verifyPassword(password))
    }

    @Test func aWrongPassword_staysOnThePasswordScreen_withAnInlineError_thenTheRightOneSignsIn() async {
        let (sut, interactor) = await atPassword(verifyPassword: .failure(AuthFailure.invalidPassword))
        await sut.send(.submitPassword("wrong"))
        #expect(sut.screen == .collectPassword(identifier: .username(username)))
        #expect(sut.inputError == .invalidPassword)

        interactor.verifyPasswordResult = .success(.authenticated)
        await sut.send(.submitPassword(password))
        #expect(sut.step == .authenticated)
        #expect(sut.inputError == nil, "cleared when the next try starts")
    }

    @Test func tooManyAttempts_staysOnThePasswordScreen() async {
        let (sut, _) = await atPassword(verifyPassword: .failure(AuthFailure.tooManyAttempts))
        await sut.send(.submitPassword(password))
        #expect(sut.screen == .collectPassword(identifier: .username(username)))
        #expect(sut.inputError == .tooManyAttempts)
    }

    @Test func aFailedPasswordCheck_endsOnAnError_andRetryReturnsToThePasswordScreen() async {
        let (sut, _) = await atPassword(
            verifyPassword: .failure(ScriptedAuthInteractor.ScriptedAuthError.scripted(message: "breached")))
        await sut.send(.submitPassword(password))
        #expect(sut.step == .failed(message: "breached"))

        await sut.send(.retry)
        #expect(sut.screen == .collectPassword(identifier: .username(username)))
    }

    @Test func whenTheAppCannotTakeTheCredentials_retryStartsAgainAtTheUsername() async {
        let (sut, _) = await atPassword(verifyPassword: .failure(CredentialsNotSavedError()))
        await sut.send(.submitPassword(password))
        guard case .failed = sut.step else { Issue.record("expected an error"); return }

        await sut.send(.retry)
        #expect(sut.step == .collectOTPIdentifier(.password), "the password was used up")
    }

    @Test func aPasswordWithoutAUsername_isIgnored() async {
        let (sut, interactor) = coordinator()
        await sut.send(.start)
        await sut.send(.submitPassword(password))
        #expect(sut.step == .collectOTPIdentifier(.password))
        #expect(interactor.receivedRequests == [.discover])
    }

    @Test func aSecondPassword_whileOneIsOnItsWay_isIgnored() async {
        let (sut, interactor) = await atPassword()
        interactor.held = [.verifyPassword]
        let first = Task { await sut.send(.submitPassword(password)) }
        await interactor.waitUntilHeld(.verifyPassword)

        await sut.send(.submitPassword(password))
        interactor.release(.verifyPassword)
        await first.value
        #expect(interactor.receivedRequests.filter {
            if case .verifyPassword = $0 { return true } else { return false }
        }.count == 1)
    }

    // MARK: Back

    @Test func backFromThePassword_returnsToTheUsernameScreen_andThenLeavesTheFlow() async {
        let (sut, _) = await atPassword()
        #expect(sut.goBack() == .movedBack)
        #expect(sut.step == .collectOTPIdentifier(.password))
        #expect(sut.goBack() == .exitFlow)
    }

    @Test func backIsIgnored_whileThePasswordIsBeingChecked() async {
        let (sut, interactor) = await atPassword()
        interactor.held = [.verifyPassword]
        let pending = Task { await sut.send(.submitPassword(password)) }
        await interactor.waitUntilHeld(.verifyPassword)

        #expect(sut.isSubmitting)
        #expect(sut.goBack() == .ignored)
        interactor.release(.verifyPassword)
        await pending.value
    }

    // MARK: More than the password

    @Test func whenTheServerWantsMore_thePasswordHandsOverToTheAdditionalStep() async {
        let (sut, _) = await atPassword(verifyPassword: .success(.additionalStepRequired(.sample())),
                                        additionalStep: provider)
        await sut.send(.submitPassword(password))
        #expect(sut.step == .additionalStep)
        #expect(provider.contexts.count == 1)
        #expect(provider.last.log == ["start"])
    }

    @Test func withoutAnAdditionalStep_aTenantThatWantsMoreIsToldNothingCanRunIt() async {
        let (sut, _) = await atPassword(verifyPassword: .success(.additionalStepRequired(.sample())))
        await sut.send(.submitPassword(password))
        #expect(sut.step == .additionalStepUnavailable)
    }

    @Test func backFromTheAdditionalStep_startsAgainAtTheFirstScreen() async {
        let (sut, _) = await atPassword(verifyPassword: .success(.additionalStepRequired(.sample())),
                                        additionalStep: provider)
        await sut.send(.submitPassword(password))
        #expect(sut.goBack() == .movedBack)
        #expect(sut.step == .collectOTPIdentifier(.password), "the password is spent")
    }
}
