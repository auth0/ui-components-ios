import Auth0
@testable import Auth0UniversalComponents
import Testing

/// How the login hands over to an additional step and takes the result back. Nothing here knows what the
/// additional step is.
@Suite
@MainActor
struct LoginFlowCoordinatorAdditionalStepTests {

    private let email = "sudhanshu.vohra@okta.com"
    private let provider = ScriptedAdditionalStepProvider()

    /// Discovery → email → code, answered with a request for an additional step.
    private func afterEmailCode(provider: AdditionalStepProviding? = nil, interactor: ScriptedAuthInteractor? = nil)
        async -> (LoginFlowCoordinator, ScriptedAuthInteractor) {
        let interactor = interactor ?? ScriptedAuthInteractor()
        interactor.discoverResult = .success([.emailOTP(connection: "email")])
        interactor.startOTPResult = .success(())
        interactor.verifyOTPResult = .success(.additionalStepRequired(.sample()))
        let sut = LoginFlowCoordinator(interactor: interactor, additionalStep: provider ?? self.provider)
        await sut.send(.start)
        await sut.send(.submitIdentifier(email))
        await sut.send(.submitOTP(code: "111111"))
        return (sut, interactor)
    }

    private func startOTPCount(_ interactor: ScriptedAuthInteractor) -> Int {
        interactor.receivedRequests.filter { $0 == .startOTP(connection: "email", email: email) }.count
    }

    // MARK: Handing over

    @Test func whenTheServerWantsMore_theAdditionalStepIsStarted_andShown() async {
        let (sut, _) = await afterEmailCode()
        #expect(sut.step == .additionalStep)
        #expect(provider.contexts.count == 1)
        #expect(provider.last.log == ["start"])
        #expect(sut.additionalStep != nil)
    }

    @Test func withoutAAdditionalStep_theLoginSaysItCannotServeIt() async {
        let (sut, _) = await afterEmailCode(provider: nil)
        let bare = LoginFlowCoordinator(interactor: ScriptedAuthInteractor(
            discover: .success([.emailOTP(connection: "email")]), startOTP: .success(()),
            verifyOTP: .success(.additionalStepRequired(.sample()))))
        await bare.send(.start)
        await bare.send(.submitIdentifier(email))
        await bare.send(.submitOTP(code: "111111"))
        #expect(bare.step == .additionalStepUnavailable)
        #expect(sut.step == .additionalStep, "the same input with an additional step plugged in")
    }

    // MARK: Taking the result back

    @Test func completed_signsIn() async {
        let (sut, _) = await afterEmailCode()
        provider.last.finish(.completed)
        #expect(sut.step == .authenticated)
    }

    @Test func cancelled_returnsToEmailEntry() async {
        let (sut, _) = await afterEmailCode()
        provider.last.finish(.cancelled)
        #expect(sut.step == .collectOTPIdentifier)
    }

    @Test func unavailable_notReported_showsTheUnavailableScreen() async {
        let (sut, _) = await afterEmailCode()
        provider.last.finish(.unavailable(reported: false))
        #expect(sut.step == .additionalStepUnavailable)
    }

    @Test func unavailable_reported_leavesTheRoutingToTheApp() async {
        let (sut, _) = await afterEmailCode()
        provider.last.finish(.unavailable(reported: true))
        #expect(sut.step == .additionalStep)
    }

    @Test func failed_staysWhereItShowsItsOwnError() async {
        let (sut, _) = await afterEmailCode()
        provider.last.finish(.failed)
        #expect(sut.step == .additionalStep)
    }

    @Test func aRestartRequest_beginsANewSignIn() async {
        let (sut, interactor) = await afterEmailCode()
        provider.last.finish(.failed)
        provider.last.requestRestart()
        for _ in 0..<200 where sut.step == .additionalStep { try? await Task.sleep(nanoseconds: 5_000_000) }
        #expect(sut.step == .collectOTPIdentifier)
        #expect(interactor.receivedRequests.filter { $0 == .discover }.count == 2)
    }

    @Test func additionalStepUnavailable_isTerminal_andSignInAgainRestarts() async {
        let (sut, interactor) = await afterEmailCode()
        provider.last.finish(.unavailable(reported: false))
        await sut.send(.restart)
        #expect(sut.step == .collectOTPIdentifier)
        #expect(interactor.receivedRequests.filter { $0 == .discover }.count == 2)
    }

    // MARK: Running again

    /// A step runs once per sign-in. A new sign-in asks the provider for a new session, with the new context.
    @Test func aProvider_isAskedForAFreshSessionEachSignIn() async {
        let (sut, _) = await afterEmailCode()
        sut.goBack()
        await sut.send(.submitIdentifier(email))
        await sut.send(.submitOTP(code: "222222"))
        #expect(sut.step == .additionalStep)
        #expect(provider.sessions.count == 2)
        #expect(provider.sessions[0] !== provider.sessions[1])
        #expect(provider.last.log == ["start"])
    }

    // MARK: Back

    @Test func back_cancelsTheAdditionalStep_andReturnsToEmailEntry() async {
        let (sut, _) = await afterEmailCode()
        #expect(sut.goBack() == .movedBack)
        #expect(provider.last.log.contains("cancel"))
        #expect(sut.step == .collectOTPIdentifier)
    }

    @Test func back_isIgnored_whileTheAdditionalStepRefusesToBeCancelled() async {
        let (sut, _) = await afterEmailCode()
        provider.last.ignoresCancel = true
        #expect(sut.goBack() == .ignored)
        #expect(sut.step == .additionalStep)
    }

    @Test func back_afterTheAdditionalStepEnded_goesToEmailEntry() async {
        let (sut, _) = await afterEmailCode()
        provider.last.finish(.failed)
        #expect(sut.goBack() == .movedBack)
        #expect(sut.step == .collectOTPIdentifier)
    }

    @Test func back_fromAdditionalStepUnavailable_goesToEmailEntry() async {
        let (sut, _) = await afterEmailCode()
        provider.last.finish(.unavailable(reported: false))
        #expect(sut.goBack() == .movedBack)
        #expect(sut.step == .collectOTPIdentifier)
    }

    // MARK: A new sign-in waits for the old one

    @Test func aNewSignIn_waitsForTheAdditionalStepsRequestInFlight() async {
        let (sut, interactor) = await afterEmailCode()
        provider.last.holdsCancel = true
        sut.goBack()

        let submitted = Task { await sut.send(.submitIdentifier(email)) }
        for _ in 0..<20 { await Task.yield() }
        try? await Task.sleep(nanoseconds: 30_000_000)
        #expect(startOTPCount(interactor) == 1, "the SDK allows one request at a time")

        provider.last.releaseCancel()
        await submitted.value
        #expect(startOTPCount(interactor) == 2)
        #expect(sut.step == .collectOTPCode(identifier: email))
        #expect(sut.additionalStep == nil)
    }
}
