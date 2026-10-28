@testable import Auth0UniversalComponents
import Testing

@Suite
@MainActor
struct LoginFlowCoordinatorTests {

    private typealias Scripted = ScriptedAuthInteractor.ScriptedAuthError

    private let email = "user@example.com"

    private func emailDiscovery(_ connection: String = "email") -> Result<[LoginOption], Error> {
        .success([.emailOTP(connection: connection)])
    }

    /// Runs discovery and submits the email, landing on code entry.
    private func atCodeEntry(_ interactor: ScriptedAuthInteractor) async -> LoginFlowCoordinator {
        let sut = LoginFlowCoordinator(interactor: interactor)
        await sut.send(.start)
        await sut.send(.submitIdentifier(email))
        return sut
    }

    // MARK: Discovery

    @Test func emailOption_advancesToIdentifier() async {
        let sut = LoginFlowCoordinator(interactor: ScriptedAuthInteractor(discover: emailDiscovery()))
        await sut.send(.start)
        #expect(sut.step == .collectOTPIdentifier)
    }

    @Test func noOptions_reportsNoMethods() async {
        let sut = LoginFlowCoordinator(interactor: ScriptedAuthInteractor(discover: .success([])))
        await sut.send(.start)
        #expect(sut.step == .noMethodsAvailable)
    }

    @Test func onlyUnsupportedOptions_reportsNoMethods() async {
        let sut = LoginFlowCoordinator(interactor: ScriptedAuthInteractor(discover: .success([.unsupported("webauthn")])))
        await sut.send(.start)
        #expect(sut.step == .noMethodsAvailable)
    }

    @Test func firstEmailOption_connectionIsUsedForStartOTP() async {
        let interactor = ScriptedAuthInteractor(
            discover: .success([.unsupported("webauthn"), .emailOTP(connection: "first"), .emailOTP(connection: "second")]),
            startOTP: .success(())
        )
        _ = await atCodeEntry(interactor)
        #expect(interactor.receivedRequests.contains(.startOTP(connection: "first", email: email)))
    }

    @Test func discoveryFailure_retry_reRunsDiscovery() async {
        let interactor = ScriptedAuthInteractor(discover: .failure(Scripted.scripted(message: "network down")))
        let sut = LoginFlowCoordinator(interactor: interactor)

        await sut.send(.start)
        #expect(sut.step == .failed(message: "network down"))

        interactor.discoverResult = emailDiscovery()
        await sut.send(.retry)
        #expect(interactor.receivedRequests == [.discover, .discover])
        #expect(sut.step == .collectOTPIdentifier)
    }

    // MARK: Email OTP

    @Test func happyPath_authenticates() async {
        let interactor = ScriptedAuthInteractor(discover: emailDiscovery(), startOTP: .success(()),
                                                verifyOTP: .success(.authenticated))
        let sut = await atCodeEntry(interactor)
        #expect(sut.step == .collectOTPCode(identifier: email))

        await sut.send(.submitOTP(code: "112233"))
        #expect(sut.step == .authenticated)
        #expect(interactor.receivedRequests == [
            .discover, .startOTP(connection: "email", email: email), .verifyOTP(code: "112233"),
        ])
    }

    @Test func resend_reSendsToSameEmail() async {
        let interactor = ScriptedAuthInteractor(discover: emailDiscovery(), startOTP: .success(()))
        let sut = await atCodeEntry(interactor)

        await sut.resendOTP()
        #expect(sut.step == .collectOTPCode(identifier: email))
        #expect(interactor.receivedRequests.filter { $0 == .startOTP(connection: "email", email: email) }.count == 2)
    }

    @Test func startOTPFailure_retry_returnsToIdentifier() async {
        let interactor = ScriptedAuthInteractor(discover: emailDiscovery(),
                                                startOTP: .failure(Scripted.scripted(message: "network down")))
        let sut = await atCodeEntry(interactor)
        #expect(sut.step == .failed(message: "network down"))

        await sut.send(.retry)
        #expect(sut.step == .collectOTPIdentifier)

        interactor.startOTPResult = .success(())
        await sut.send(.submitIdentifier(email))
        #expect(sut.step == .collectOTPCode(identifier: email))
    }

    @Test func codeNotSent_staysOnIdentifierWithInlineError() async {
        let interactor = ScriptedAuthInteractor(discover: emailDiscovery(),
                                                startOTP: .failure(AuthFailure.codeNotSent))
        let sut = await atCodeEntry(interactor)
        #expect(sut.step == .collectOTPIdentifier)
        #expect(sut.inputError == .codeNotSent)

        interactor.startOTPResult = .success(())
        await sut.send(.submitIdentifier(email))
        #expect(sut.step == .collectOTPCode(identifier: email))
        #expect(sut.inputError == nil)
    }

    @Test func nonLocalizedError_usesFallbackMessage() async {
        struct Opaque: Error {}
        let sut = LoginFlowCoordinator(interactor: ScriptedAuthInteractor(discover: .failure(Opaque())))
        await sut.send(.start)
        #expect(sut.step == .failed(message: "Something went wrong. Please try again."))
    }

    // MARK: Inline code errors

    @Test(arguments: [AuthFailure.invalidCode, .tooManyAttempts])
    func rejectedCode_staysOnCodeScreen(_ failure: AuthFailure) async {
        let interactor = ScriptedAuthInteractor(discover: emailDiscovery(), startOTP: .success(()),
                                                verifyOTP: .failure(failure))
        let sut = await atCodeEntry(interactor)

        await sut.send(.submitOTP(code: "000000"))
        #expect(sut.step == .collectOTPCode(identifier: email))
        #expect(sut.inputError == failure)
    }

    @Test func verifySystemError_goesFullScreen() async {
        let interactor = ScriptedAuthInteractor(discover: emailDiscovery(), startOTP: .success(()),
                                                verifyOTP: .failure(Scripted.scripted(message: "network down")))
        let sut = await atCodeEntry(interactor)

        await sut.send(.submitOTP(code: "112233"))
        #expect(sut.step == .failed(message: "network down"))
        #expect(sut.inputError == nil)

        await sut.send(.retry)
        #expect(sut.step == .collectOTPCode(identifier: email))
    }

    @Test func resubmit_clearsInlineError() async {
        let interactor = ScriptedAuthInteractor(discover: emailDiscovery(), startOTP: .success(()),
                                                verifyOTP: .failure(AuthFailure.invalidCode))
        let sut = await atCodeEntry(interactor)
        await sut.send(.submitOTP(code: "000000"))
        #expect(sut.inputError == .invalidCode)

        interactor.verifyOTPResult = .success(.authenticated)
        await sut.send(.submitOTP(code: "112233"))
        #expect(sut.inputError == nil)
        #expect(sut.step == .authenticated)
    }

    // MARK: Back

    @Test func back_fromCodeEntry_returnsToIdentifier() async {
        let sut = await atCodeEntry(ScriptedAuthInteractor(discover: emailDiscovery(), startOTP: .success(())))
        #expect(sut.goBack() == .movedBack)
        #expect(sut.step == .collectOTPIdentifier)
    }

    @Test func back_fromCodeEntry_keepsTheEmail() async {
        let sut = await atCodeEntry(ScriptedAuthInteractor(discover: emailDiscovery(), startOTP: .success(())))
        sut.goBack()
        #expect(sut.enteredEmail == email)
    }

    @Test func failedSubmit_retry_keepsTheTypedEmail() async {
        let failing = ScriptedAuthInteractor(discover: emailDiscovery(),
                                             startOTP: .failure(Scripted.scripted(message: "network down")))
        let sut = await atCodeEntry(failing)
        await sut.send(.retry)
        #expect(sut.step == .collectOTPIdentifier)
        #expect(sut.enteredEmail == email)
    }

    @Test func back_fromIdentifier_exitsFlow() async {
        let sut = LoginFlowCoordinator(interactor: ScriptedAuthInteractor(discover: emailDiscovery()))
        await sut.send(.start)
        #expect(sut.goBack() == .exitFlow)
    }

    @Test func back_whileVerifying_isIgnored() async {
        let interactor = ScriptedAuthInteractor(discover: emailDiscovery(), startOTP: .success(()),
                                                verifyOTP: .success(.authenticated))
        let sut = await atCodeEntry(interactor)
        interactor.held = [.verifyOTP]

        let verify = Task { await sut.send(.submitOTP(code: "112233")) }
        await interactor.waitUntilHeld(.verifyOTP)
        #expect(sut.isSubmitting)
        #expect(sut.goBack() == .ignored)

        interactor.release(.verifyOTP)
        await verify.value
        #expect(sut.step == .authenticated)
        #expect(!sut.isSubmitting)
    }

    @Test func back_whileResending_isIgnored() async {
        let interactor = ScriptedAuthInteractor(discover: emailDiscovery(), startOTP: .success(()))
        let sut = await atCodeEntry(interactor)
        interactor.held = [.startOTP]

        let resend = Task { await sut.resendOTP() }
        await interactor.waitUntilHeld(.startOTP)
        #expect(sut.goBack() == .ignored)

        interactor.release(.startOTP)
        await resend.value
        #expect(sut.goBack() == .movedBack)
    }

    @Test func back_duringDiscovery_exitsFlow() async {
        let interactor = ScriptedAuthInteractor(discover: emailDiscovery())
        interactor.held = [.discover]
        let sut = LoginFlowCoordinator(interactor: interactor)

        let start = Task { await sut.send(.start) }
        await interactor.waitUntilHeld(.discover)
        #expect(!sut.isSubmitting)
        #expect(sut.goBack() == .exitFlow)

        interactor.release(.discover)
        await start.value
    }

    // MARK: Re-entry

    @Test func doubleSubmitIdentifier_startsOTPOnce() async {
        let interactor = ScriptedAuthInteractor(discover: emailDiscovery(), startOTP: .success(()))
        interactor.held = [.startOTP]
        let sut = LoginFlowCoordinator(interactor: interactor)
        await sut.send(.start)

        let first = Task { await sut.send(.submitIdentifier(email)) }
        await interactor.waitUntilHeld(.startOTP)
        await sut.send(.submitIdentifier(email))

        interactor.release(.startOTP)
        await first.value
        #expect(interactor.receivedRequests == [.discover, .startOTP(connection: "email", email: email)])
        #expect(sut.step == .collectOTPCode(identifier: email))
    }

    @Test func doubleSubmitOTP_verifiesOnce() async {
        let interactor = ScriptedAuthInteractor(discover: emailDiscovery(), startOTP: .success(()),
                                                verifyOTP: .success(.authenticated))
        let sut = await atCodeEntry(interactor)
        interactor.held = [.verifyOTP]

        let first = Task { await sut.send(.submitOTP(code: "112233")) }
        await interactor.waitUntilHeld(.verifyOTP)
        await sut.send(.submitOTP(code: "112233"))
        await sut.resendOTP()

        interactor.release(.verifyOTP)
        await first.value
        #expect(interactor.receivedRequests.filter { $0 == .verifyOTP(code: "112233") }.count == 1)
        #expect(interactor.receivedRequests.filter { $0 == .startOTP(connection: "email", email: email) }.count == 1)
        #expect(sut.step == .authenticated)
    }

    // MARK: Credentials storage

    @Test func credentialsNotSaved_goesFullScreen_retryReturnsToIdentifier() async {
        let interactor = ScriptedAuthInteractor(discover: emailDiscovery(), startOTP: .success(()),
                                                verifyOTP: .failure(CredentialsNotSavedError()))
        let sut = await atCodeEntry(interactor)

        await sut.send(.submitOTP(code: "112233"))
        #expect(sut.step == .failed(message: "We couldn't save your sign-in on this device. Please try again."))

        await sut.send(.retry)
        #expect(sut.step == .collectOTPIdentifier)
    }
}
