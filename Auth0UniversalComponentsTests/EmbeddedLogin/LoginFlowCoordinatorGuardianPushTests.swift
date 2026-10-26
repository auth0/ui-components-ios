@testable import Auth0UniversalComponents
import Testing

@Suite
@MainActor
struct LoginFlowCoordinatorGuardianPushTests {

    private let email = "sudhanshu.vohra@okta.com"
    private let phone = GuardianPushDevice(index: 0, name: "Sudhanshu's iPhone")
    private let tablet = GuardianPushDevice(index: 1, name: "Sudhanshu's iPhone")

    /// Discovery → email → code, answered with `progress`.
    /// - Parameter waitsForever: Push waits never end (for cases that stay on the waiting screen).
    private func afterEmailCode(_ progress: AuthProgress,
                                _ scripted: ScriptedAuthInteractor? = nil,
                                waitsForever: Bool = false) async -> (LoginFlowCoordinator, ScriptedAuthInteractor) {
        let interactor = scripted ?? ScriptedAuthInteractor()
        interactor.discoverResult = .success([.emailOTP(connection: "email")])
        interactor.startOTPResult = .success(())
        interactor.verifyOTPResult = .success(progress)
        let sut = LoginFlowCoordinator(interactor: interactor, pushSleep: { _ in
            if waitsForever { try await Task.sleep(nanoseconds: .max) }
        })
        await sut.send(.start)
        await sut.send(.submitIdentifier(email))
        await sut.send(.submitOTP(code: "111111"))
        return (sut, interactor)
    }

    private func eventually(_ condition: () -> Bool) async {
        for _ in 0..<10_000 where !condition() { await Task.yield() }
    }

    /// A push client whose approval check stays pending.
    private func neverApproves() -> AnyGuardianPushClient<Void> {
        AnyGuardianPushClient(sendPush: { _ in GuardianPushPending(retryAfter: 60_000) },
                              checkApproval: { .pending(GuardianPushPending(retryAfter: 60_000)) })
    }

    @Test func pushDevice_startsGuardianPush() async {
        let interactor = ScriptedAuthInteractor()
        interactor.pushClient = neverApproves()
        let (sut, _) = await afterEmailCode(.guardianPush([phone]), interactor, waitsForever: true)

        #expect(sut.step == .guardianPush)
        await eventually { sut.pushController?.state == .waiting(phone, canResend: false) }
        #expect(sut.pushController?.state == .waiting(phone, canResend: false))
    }

    @Test func approval_authenticates() async {
        let (sut, _) = await afterEmailCode(.guardianPush([phone]))
        await eventually { sut.step == .authenticated }
        #expect(sut.step == .authenticated)
    }

    @Test func noPushDevice_showsTheTerminalState() async {
        let (sut, _) = await afterEmailCode(.guardianPush([]))
        #expect(sut.step == .guardianPush)
        #expect(sut.pushController?.state == .failed(.unavailable))
    }

    @Test func back_fromPush_restartsAtEmailEntry() async {
        let interactor = ScriptedAuthInteractor()
        interactor.pushClient = neverApproves()
        let (sut, _) = await afterEmailCode(.guardianPush([phone]), interactor, waitsForever: true)

        #expect(sut.goBack() == .movedBack)
        #expect(sut.step == .collectOTPIdentifier)

        await sut.send(.submitIdentifier(email))
        #expect(sut.pushController == nil)
        #expect(interactor.receivedRequests.filter { $0 == .startOTP(connection: "email", email: email) }.count == 2)
    }

    @Test func back_withSeveralDevices_returnsToTheList() async {
        let interactor = ScriptedAuthInteractor()
        interactor.pushClient = neverApproves()
        let (sut, _) = await afterEmailCode(.guardianPush([phone, tablet]), interactor, waitsForever: true)
        sut.pushController?.select(tablet)
        await eventually { if case .waiting = sut.pushController?.state { return true } else { return false } }

        #expect(sut.goBack() == .movedBack)
        #expect(sut.pushController?.state == .choosingDevice([phone, tablet]))

        #expect(sut.goBack() == .movedBack)
        #expect(sut.step == .collectOTPIdentifier)
    }

    @Test func restart_opensANewSignIn() async {
        let interactor = ScriptedAuthInteractor()
        interactor.pushClient = AnyGuardianPushClient(sendPush: { _ in GuardianPushPending(retryAfter: 1_000) },
                                                      checkApproval: { throw GuardianPushFailure.denied })
        let (sut, _) = await afterEmailCode(.guardianPush([phone]), interactor)
        await eventually { sut.pushController?.state == .failed(.denied) }

        await sut.send(.restart)

        #expect(sut.step == .collectOTPIdentifier)
        #expect(sut.pushController == nil)
        #expect(interactor.receivedRequests.filter { $0 == .discover }.count == 2)
    }
}
