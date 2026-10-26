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

    /// Holds the approval check on the wire until `release()`, then approves.
    @MainActor
    private final class HeldApproval {
        private(set) var isInFlight = false
        private var gate: CheckedContinuation<Void, Never>?

        var client: AnyGuardianPushClient<Void> {
            AnyGuardianPushClient(sendPush: { _ in GuardianPushPending(retryAfter: 1_000) },
                                  checkApproval: { [unowned self] in
                                      isInFlight = true
                                      await withCheckedContinuation { gate = $0 }
                                      return .approved(())
                                  })
        }

        func release() { gate?.resume() }
    }

    /// The approval was already on its way at Back: the credentials are stored, so the user is signed in.
    @Test func back_duringAnApprovingCheck_stillSignsIn() async {
        let held = HeldApproval()
        let interactor = ScriptedAuthInteractor()
        interactor.pushClient = held.client
        let (sut, _) = await afterEmailCode(.guardianPush([phone]), interactor)
        await eventually { held.isInFlight }

        #expect(sut.goBack() == .movedBack)
        #expect(sut.step == .collectOTPIdentifier)
        // Leaving now would orphan the approval.
        #expect(sut.isDrainingPush)
        #expect(sut.goBack() == .ignored)

        held.release()
        await eventually { sut.step == .authenticated && !sut.isDrainingPush }

        #expect(sut.step == .authenticated)
        #expect(!sut.isDrainingPush)
    }

    @Test func emailSubmitted_whileAnApprovingCheckIsInFlight_staysSignedIn() async {
        let held = HeldApproval()
        let interactor = ScriptedAuthInteractor()
        interactor.pushClient = held.client
        let (sut, _) = await afterEmailCode(.guardianPush([phone]), interactor)
        await eventually { held.isInFlight }
        sut.goBack()

        async let submitted: Void = sut.send(.submitIdentifier(email))
        await eventually { sut.isSubmitting }
        held.release()
        await submitted

        #expect(sut.step == .authenticated)
        #expect(interactor.receivedRequests.filter { $0 == .startOTP(connection: "email", email: email) }.count == 1)
    }

    @Test func back_afterADenial_withSeveralDevices_goesToEmailEntry() async {
        final class Sends { var count = 0 }
        let sends = Sends()
        let interactor = ScriptedAuthInteractor()
        interactor.pushClient = AnyGuardianPushClient(sendPush: { _ in
            sends.count += 1
            return GuardianPushPending(retryAfter: 1_000)
        }, checkApproval: { throw GuardianPushFailure.denied })
        let (sut, _) = await afterEmailCode(.guardianPush([phone, tablet]), interactor)
        sut.pushController?.select(tablet)
        await eventually { sut.pushController?.state == .failed(.denied) }

        #expect(sut.goBack() == .movedBack)

        #expect(sut.step == .collectOTPIdentifier)
        #expect(sut.pushController?.state == .failed(.denied))
        #expect(sends.count == 1)
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
