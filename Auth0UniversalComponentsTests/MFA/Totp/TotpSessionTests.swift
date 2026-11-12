@testable import Auth0UniversalComponents
import Testing

@MainActor
final class ScriptedTotpTransport: TotpTransport {
    var verifies: [Result<TotpVerification, MfaError>]
    private(set) var log: [String] = []

    init(verify: [Result<TotpVerification, MfaError>] = []) {
        verifies = verify
    }

    func verify(code: String, while isWanted: () -> Bool) async throws -> TotpVerification {
        log.append("verify \(code)")
        return try (verifies.isEmpty ? .success(.verified) : verifies.removeFirst()).get()
    }
}

/// The authenticator app session on its own, with a fake Core around it.
@Suite
@MainActor
struct TotpSessionTests {

    private let host = FakeHost()

    private func session(_ transport: ScriptedTotpTransport) -> TotpSession {
        TotpSession(transport: transport, host: host)
    }

    private func model(_ session: TotpSession) -> TotpChallengeModel? {
        session.model as? TotpChallengeModel
    }

    @Test func theCodeScreenIsUpAtOnce_withNothingSent() {
        let transport = ScriptedTotpTransport()
        let sut = session(transport)
        #expect(sut.model == nil, "before it starts there is nothing to show")
        sut.start()
        #expect(model(sut)?.codeLength == 6)
        #expect(model(sut)?.isVerifying == false)
        #expect(transport.log.isEmpty)
        #expect(host.changes == 1)
    }

    @Test func canSwitch_followsTheCore() {
        host.canSwitch = true
        let sut = session(ScriptedTotpTransport())
        sut.start()
        #expect(model(sut)?.canSwitch == true)
    }

    @Test func theRightCode_reportsCompletedOnce() async {
        let transport = ScriptedTotpTransport()
        let sut = session(transport)
        sut.start()

        model(sut)?.submit("123456")
        #expect(model(sut)?.isVerifying == true)
        await eventually { host.events == ["completed"] }
        #expect(transport.log == ["verify 123456"])
        #expect(host.events == ["completed"])
    }

    @Test func aWrongCode_staysOnTheScreen_thenTheRightOneCompletes() async {
        let transport = ScriptedTotpTransport(verify: [.success(.rejected)])
        let sut = session(transport)
        sut.start()

        model(sut)?.submit("000000")
        await eventually { model(sut)?.isCodeRejected == true }
        #expect(model(sut)?.isVerifying == false)
        #expect(host.events.isEmpty)

        model(sut)?.submit("123456")
        await eventually { host.events == ["completed"] }
        #expect(transport.log == ["verify 000000", "verify 123456"])
    }

    @Test func aDroppedConnection_keepsTheScreen_withTheReason() async {
        let sut = session(ScriptedTotpTransport(verify: [.failure(.network)]))
        sut.start()

        model(sut)?.submit("123456")
        await eventually { model(sut)?.requestError == .network }
        #expect(model(sut)?.isVerifying == false)
        #expect(host.events.isEmpty)
    }

    @Test func tooManyWrongCodes_endTheFlow() async {
        let sut = session(ScriptedTotpTransport(verify: [.failure(.tooManyAttempts)]))
        sut.start()

        model(sut)?.submit("123456")
        await eventually { host.events == ["failed"] }
        #expect(host.errors == [.tooManyAttempts])
    }

    @Test func aCodeThatAsksForAnotherFactor_handsTheMenuToTheCore() async {
        let next = [MfaFactorOffer(id: "push:0", factor: .push, label: "iPhone", reference: 0)]
        let sut = session(ScriptedTotpTransport(verify: [.success(.anotherFactor(next))]))
        sut.start()

        model(sut)?.submit("123456")
        await eventually { host.events == ["menu"] }
        #expect(host.offers == [next])
    }

    @Test func switchingAndCancelling_goThroughTheCore() {
        let sut = session(ScriptedTotpTransport())
        sut.start()
        model(sut)?.switchFactor()
        model(sut)?.cancel()
        #expect(host.events == ["switch", "cancel"])
    }

    @Test func afterDeactivate_noNewCodeIsChecked() async {
        let transport = ScriptedTotpTransport()
        let sut = session(transport)
        sut.start()
        let screen = model(sut)

        sut.deactivate()
        screen?.submit("123456")
        await settle()
        #expect(transport.log.isEmpty)
    }

    @Test func afterTheFlowIsOver_nothingIsReported() async {
        let transport = ScriptedTotpTransport()
        let sut = session(transport)
        sut.start()
        let screen = model(sut)

        await sut.cancelAndWait()
        screen?.submit("123456")
        await settle()
        #expect(transport.log.isEmpty)
        #expect(host.events.isEmpty)
    }
}
