@testable import Auth0UniversalComponents
import Testing

@MainActor
final class ScriptedPushTransport: PushTransport {
    var sends: [Result<PushPending, MfaError>]
    var checks: [Result<PushCheck, MfaError>]
    private(set) var log: [String] = []
    /// Keeps the next check "on the wire" until released.
    var holdNextCheck = false
    private var held: CheckedContinuation<Void, Never>?

    init(send: [Result<PushPending, MfaError>] = [], check: [Result<PushCheck, MfaError>] = []) {
        sends = send
        checks = check
    }

    func releaseHeldCheck() {
        held?.resume()
        held = nil
    }

    func sendPush(to offer: MfaFactorOffer) async throws -> PushPending {
        log.append("send \(offer.id)")
        let fallback = Result<PushPending, MfaError>.success(PushPending(retryAfterMs: 2_000, canResend: true))
        return try (sends.isEmpty ? fallback : sends.removeFirst()).get()
    }

    func checkApproval() async throws -> PushCheck {
        log.append("check")
        if holdNextCheck {
            holdNextCheck = false
            await withCheckedContinuation { (continuation: CheckedContinuation<Void, Never>) in held = continuation }
        }
        return try (checks.isEmpty ? .success(.pending(retryAfterMs: nil)) : checks.removeFirst()).get()
    }
}

/// The push session on its own, with a fake Core around it.
@Suite
@MainActor
struct PushSessionTests {

    private let offer = scriptedOffer("push:0", factor: .push, label: "iPhone")
    private let clock = ManualMfaClock()
    private let host = FakeHost()

    private func session(_ transport: ScriptedPushTransport) -> PushSession {
        PushSession(offer: offer, transport: transport, policy: .default, clock: clock, host: host)
    }

    private func model(_ session: PushSession) -> PushChallengeModel? { session.model as? PushChallengeModel }

    @Test func sendingShowsNothing_thenTheWaitingModel() async {
        let sut = session(ScriptedPushTransport())
        sut.start()
        #expect(sut.model == nil, "the factor is still preparing")
        await eventually { model(sut) != nil }
        #expect(model(sut)?.deviceName == "iPhone")
        #expect(model(sut)?.canResend == true)
        #expect(model(sut)?.canSwitch == false)
    }

    @Test func pollsUntilApproved_thenReportsCompletedOnce() async {
        let transport = ScriptedPushTransport(check: [.success(.pending(retryAfterMs: nil)), .success(.approved)])
        let sut = session(transport)
        sut.start()
        await settle()
        await clock.advance()
        await settle()
        await clock.advance()
        await eventually { host.events == ["completed"] }
        #expect(transport.log == ["send push:0", "check", "check"])
        #expect(host.events == ["completed"])
    }

    @Test func comingBackToTheForeground_checksWithoutWaitingForTheTimer() async {
        let transport = ScriptedPushTransport(check: [.success(.approved)])
        let sut = session(transport)
        sut.start()
        await settle()
        sut.appBecameActive()
        await eventually { host.events == ["completed"] }
        #expect(transport.log == ["send push:0", "check"])
        #expect(host.events == ["completed"])
    }

    @Test func resend_sendsAgain_andKeepsTheWaitingScreenWithoutAResendButton() async {
        let sut = session(ScriptedPushTransport())
        sut.start()
        await settle()
        model(sut)?.resend()
        #expect(model(sut)?.deviceName == "iPhone", "the screen stays up while the new push goes out")
        #expect(model(sut)?.canResend == false, "and offers no second resend meanwhile")
        await eventually { model(sut)?.canResend == true }
        #expect(model(sut)?.canResend == true, "once it is out, resend is possible again")
    }

    @Test func theModelsActions_reachTheCore() async {
        let sut = session(ScriptedPushTransport())
        sut.start()
        await settle()
        model(sut)?.switchFactor()
        model(sut)?.cancel()
        #expect(host.events == ["switch", "cancel"])
    }

    @Test func deactivated_noCheckIsEverSent() async {
        let transport = ScriptedPushTransport()
        let sut = session(transport)
        sut.start()
        await settle()
        sut.deactivate()
        await clock.advance()
        await settle()
        #expect(!transport.log.contains("check"))
    }

    @Test func deactivated_anApprovalOnTheWire_isStillReported() async {
        let transport = ScriptedPushTransport(check: [.success(.approved)])
        transport.holdNextCheck = true
        let sut = session(transport)
        sut.start()
        await settle()
        await clock.advance()
        await eventually { transport.log.contains("check") }        // the check is on the wire, held
        sut.deactivate()
        transport.releaseHeldCheck()
        await eventually { host.events == ["completed"] }
        #expect(host.events == ["completed"])
    }

    @Test func stopped_nothingIsReportedAfterwards_andCancelWaitsForTheRequestInFlight() async {
        let transport = ScriptedPushTransport(check: [.success(.approved)])
        transport.holdNextCheck = true
        let sut = session(transport)
        sut.start()
        await settle()
        sut.appBecameActive()
        await eventually { transport.log.contains("check") }        // the check is on the wire, held
        var returned = false
        let waiter = Task { @MainActor in
            await sut.cancelAndWait()
            returned = true
        }
        await settle()
        #expect(!returned, "the check is still on the wire")
        transport.releaseHeldCheck()
        await waiter.value
        #expect(returned)
        #expect(host.events.isEmpty, "the flow is over; an approval after that is dropped")
    }

    @Test func aFailure_isReported() async {
        let sut = session(ScriptedPushTransport(send: [.failure(.rejected)]))
        sut.start()
        await eventually { host.errors == [.rejected] }
        #expect(host.errors == [.rejected])
    }

    @Test func anApprovalThatAsksForAnotherFactor_isReportedWithTheMenu() async {
        let menu = [scriptedOffer("push:1", factor: .push)]
        let sut = session(ScriptedPushTransport(check: [.success(.anotherFactor(menu))]))
        sut.start()
        await settle()
        sut.appBecameActive()
        await settle()
        #expect(host.events == ["menu"])
        #expect(host.offers == [menu])
    }

    @Test func pushRowsAreWordedByThePushFactor() {
        let factor = PushFactor(transport: ScriptedPushTransport())
        let named = factor.row(for: offer, messages: .default)
        #expect(named.title == "iPhone")
        #expect(named.subtitle == "Push notification")
        let anonymous = factor.row(for: scriptedOffer("push:2", factor: .push), messages: .default)
        #expect(anonymous.title == "Push notification")
        #expect(factor.rank == 20)
        #expect(factor.id == .push)
    }
}
