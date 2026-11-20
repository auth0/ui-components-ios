import Auth0
import Foundation
import Testing
@testable import Auth0UniversalComponents

/// What the user sees when a step fails: a fault they can fix on the screen, one that ends the sign-up (the SDK has
/// closed its session, so only "Start over" can follow), and a request that never arrived (the session is still there).
@MainActor
@Suite struct SignupFlowCoordinatorFailureTests {

    private typealias Fixtures = SignupHarness.Fixtures
    private let email = SignupHarness.email

    // MARK: Codes 

    @Test func aWrongCode_staysOnTheCodeScreen_andTheRightOneContinues() async {
        let harness = SignupHarness()
        harness.client.scripted.verifyOtpResults = [
            .failure(Fixtures.needs([Fixtures.verifyEmail, Fixtures.challengeEmail],
                                    subReason: "invalid_identifier_or_code")),
            .failure(Fixtures.needs([Fixtures.confirmSignup]))
        ]
        await harness.onTheCodeScreen()

        await harness.sut.send(.submitCode("000000"))
        #expect(harness.sut.inputError == .invalidCode)
        guard case .collectCode = harness.sut.step else { Issue.record("\(harness.sut.step)"); return }

        await harness.sut.send(.submitCode("123456"))
        #expect(harness.sut.step == .confirm)
        #expect(harness.sut.inputError == nil)
    }

    @Test func resend_asksForTheSameCodeAgain_onTheSameScreen() async {
        let harness = SignupHarness()
        harness.client.scripted.challengeEmailResults += [
            Fixtures.needs([Fixtures.verifyEmail, Fixtures.challengeEmail])]
        await harness.onTheCodeScreen()
        let screen = harness.sut.step

        await harness.sut.send(.resend)

        #expect(harness.sut.step == screen)
        #expect(harness.client.calls.filter { $0 == .challengeEmail(index: 1) }.count == 2)
    }

    @Test func tooManyWrongCodes_endsTheSignup_andStartOverOpensANewOne() async {
        let harness = SignupHarness()
        harness.client.scripted.verifyOtpResults = [
            .failure(Fixtures.terminal("access_denied", description: "too_many_wrong_otp_attempts"))]
        await harness.onTheCodeScreen()

        await harness.sut.send(.submitCode("000000"))
        #expect(harness.sut.step == .failed(message: SignupFailure.tooManyWrongCodes.message(for: .email),
                                                    canRetry: false))

        // The session is gone, and a retry would hit a dead one: only a new sign-up helps.
        harness.client.scripted.authorizeResults = [Fixtures.needs([Fixtures.signup()])]
        harness.client.scripted.signupResults = [Fixtures.needs([Fixtures.identifyEmail])]
        await harness.sut.send(.restart)
        #expect(harness.sut.step == .collectIdentifier(.email))
        #expect(harness.client.calls.filter { $0 == .authorize(connection: "db") }.count == 2)
    }

    @Test func tooManyCodesRequested_endsTheSignup() async {
        let harness = SignupHarness()
        harness.client.scripted.challengeEmailResults += [
            Fixtures.terminal("access_denied", description: "too_many_resend_attempts")]
        await harness.onTheCodeScreen()

        await harness.sut.send(.resend)

        #expect(harness.sut.step == .failed(message: SignupFailure.tooManyCodesRequested.message(for: .email),
                                                    canRetry: false))
    }

    /// The SDK closes its session on a rate limit, so the user can't carry on where they were: another try would hit
    /// `no_active_session` and loop. Only a new sign-up helps.
    @Test func aRateLimit_endsTheSignup_andStartOverOpensANewOne() async {
        let harness = SignupHarness()
        harness.client.scripted.verifyOtpResults = [.failure(Fixtures.rateLimited)]
        await harness.onTheCodeScreen()

        await harness.sut.send(.submitCode("123456"))
        #expect(harness.sut.step == .failed(message: SignupFailure.tooManyAttempts.message(for: .email),
                                                    canRetry: false))
        #expect(!harness.client.hasSession)

        harness.client.scripted.authorizeResults = [Fixtures.needs([Fixtures.signup()])]
        harness.client.scripted.signupResults = [Fixtures.needs([Fixtures.identifyEmail])]
        await harness.sut.send(.restart)
        #expect(harness.sut.step == .collectIdentifier(.email))
        #expect(harness.client.hasSession)
    }

    @Test func aServerError_endsTheSignup_insteadOfOfferingATryAgainThatCantWork() async {
        let harness = SignupHarness()
        harness.client.scripted.identifyResults = [
            Fixtures.terminal("server_error", description: "boom", statusCode: 500)]
        await harness.sut.send(.start)

        await harness.sut.send(.submitIdentifier(email))

        #expect(harness.sut.step == .failed(message: SignupFailure.ended.message(for: .email),
                                                    canRetry: false))
        // "Try again" is not offered, and the session is gone: nothing but a new sign-up would work.
        await harness.sut.send(.retry)
        #expect(harness.sut.step == .failed(message: SignupFailure.ended.message(for: .email),
                                                    canRetry: false))
    }

    @Test func aFailureOpeningTheSignup_thatTheServerEnded_isNotRetried() async {
        let harness = SignupHarness()
        harness.client.scripted.authorizeResults = [
            Fixtures.terminal("server_error", description: "x", statusCode: 500)]
        await harness.sut.send(.start)
        #expect(harness.sut.step == .failed(message: SignupFailure.ended.message(for: .email),
                                                    canRetry: false))
    }

    @Test func startingAgain_whileAlreadyStarted_changesNothing() async {
        let harness = SignupHarness()
        await harness.sut.send(.start)
        await harness.sut.send(.submitIdentifier(email))
        let screen = harness.sut.step

        await harness.sut.send(.start)

        #expect(harness.sut.step == screen)
        #expect(harness.client.calls.filter { $0 == .authorize(connection: "db") }.count == 1)
    }

    @Test func aConfirm_fromAnyOtherScreen_isIgnored() async {
        let harness = SignupHarness()
        await harness.onTheCodeScreen()

        await harness.sut.send(.confirm)

        #expect(!harness.client.calls.contains(.confirmSignup))
    }

    @Test func anEntry_fromAnyOtherScreen_isIgnored() async {
        let harness = SignupHarness()
        await harness.onTheCodeScreen()

        await harness.sut.send(.submitIdentifier(email))

        #expect(harness.client.calls.filter { $0 == .identify("sarah.doe@example.com", type: .email) }.count == 1)
    }

    // MARK: Failures that go full screen

    @Test func aNetworkFailure_offersTryAgain_andReturnsToTheStepThatFailed() async {
        let harness = SignupHarness()
        harness.client.scripted.identifyResults = [Fixtures.network,
                                                   Fixtures.needs([Fixtures.challengeEmail, Fixtures.identifyEmail])]
        await harness.sut.send(.start)

        await harness.sut.send(.submitIdentifier(email))
        guard case .failed(_, canRetry: true) = harness.sut.step else { Issue.record("\(harness.sut.step)"); return }

        await harness.sut.send(.retry)
        #expect(harness.sut.step == .collectIdentifier(.email))

        await harness.sut.send(.submitIdentifier(email))
        guard case .collectCode = harness.sut.step else { Issue.record("\(harness.sut.step)"); return }
    }

    @Test func aFailureOpeningTheSignup_triesAgainFromTheStart() async {
        let harness = SignupHarness()
        harness.client.scripted.authorizeResults = [Fixtures.network, Fixtures.needs([Fixtures.signup()])]
        await harness.sut.send(.start)
        guard case .failed(_, canRetry: true) = harness.sut.step else { Issue.record("\(harness.sut.step)"); return }

        await harness.sut.send(.retry)

        #expect(harness.sut.step == .collectIdentifier(.email))
    }

    @Test func aNetworkFailureCreatingTheAccount_keepsTheSession_soTryAgainConfirmsAgain() async {
        let harness = SignupHarness()
        harness.client.scripted.confirmSignupResults = [.failure(Fixtures.network), .success(Credentials())]
        await harness.onTheCodeScreen()
        await harness.sut.send(.submitCode("123456"))

        await harness.sut.send(.confirm)
        guard case .failed(_, canRetry: true) = harness.sut.step else { Issue.record("\(harness.sut.step)"); return }
        await harness.sut.send(.retry)
        #expect(harness.sut.step == .confirm)

        await harness.sut.send(.confirm)
        #expect(harness.sut.step == .created)
        await harness.sut.send(.finish)
        #expect(harness.sut.step == .authenticated)
        #expect(harness.delivered.credentials.count == 1)
    }

    @Test func aSignupTheServerDenies_endsWithoutARetry() async {
        let harness = SignupHarness()
        harness.client.scripted.confirmSignupResults = [
            .failure(Fixtures.terminal("access_denied", description: "denied"))]
        await harness.onTheCodeScreen()
        await harness.sut.send(.submitCode("123456"))

        await harness.sut.send(.confirm)

        #expect(harness.sut.step == .failed(message: SignupFailure.denied.message(for: .email),
                                                    canRetry: false))
    }

    @Test func aConfirmThatNeedsMore_isAFailureNotAHang() async {
        let harness = SignupHarness()
        harness.client.scripted.confirmSignupResults = [.failure(Fixtures.needs([Fixtures.verifyEmail]))]
        await harness.onTheCodeScreen()
        await harness.sut.send(.submitCode("123456"))

        await harness.sut.send(.confirm)

        // Sending the confirmation again would get the same answer: only a new sign-up can help.
        #expect(harness.sut.step == .failed(message: SignupFailure.ended.message(for: .email),
                                                    canRetry: false))
        #expect(harness.delivered.credentials.isEmpty)
    }

    @Test func whenTheAppCantTakeTheCredentials_theSignupEndsAsNotSaved() async {
        let harness = SignupHarness()
        harness.delivered.failsToSave = true
        await harness.onTheCodeScreen()
        await harness.sut.send(.submitCode("123456"))
        await harness.sut.send(.confirm)

        await harness.sut.send(.finish)

        let message = CredentialsNotSavedError().errorDescription ?? ""
        #expect(harness.sut.step == .failed(message: message, canRetry: false))
    }

    @Test func whenTheAppCantTakeTheCredentialsOfAnExistingAccount_theSignupEndsAsNotSaved() async {
        let harness = SignupHarness()
        harness.client.scripted.verifyOtpResults = [.success(Credentials())]
        harness.delivered.failsToSave = true
        await harness.onTheCodeScreen()

        await harness.sut.send(.submitCode("123456"))

        let message = CredentialsNotSavedError().errorDescription ?? ""
        #expect(harness.sut.step == .failed(message: message, canRetry: false))
    }
}
