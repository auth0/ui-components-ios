@testable import Auth0UniversalComponents
import Testing

@MainActor
final class ScriptedRecoveryCodeTransport: RecoveryCodeTransport {
    var verifies: [Result<RecoveryCodeVerification, MfaError>]
    var confirms: [Result<RecoveryCodeConfirmation, MfaError>]
    private(set) var log: [String] = []

    init(verify: [Result<RecoveryCodeVerification, MfaError>] = [],
         confirm: [Result<RecoveryCodeConfirmation, MfaError>] = []) {
        verifies = verify
        confirms = confirm
    }

    func verify(code: String, while isWanted: () -> Bool) async throws -> RecoveryCodeVerification {
        log.append("verify \(code)")
        return try (verifies.isEmpty ? .success(.rotated(newCode: "NEW")) : verifies.removeFirst()).get()
    }

    func confirm(while isWanted: () -> Bool) async throws -> RecoveryCodeConfirmation {
        log.append("confirm")
        return try (confirms.isEmpty ? .success(.verified) : confirms.removeFirst()).get()
    }
}

/// The recovery code session on its own, with a fake Core around it.
@Suite
@MainActor
struct RecoveryCodeSessionTests {

    private let host = FakeHost()

    private func session(_ transport: ScriptedRecoveryCodeTransport) -> RecoveryCodeSession {
        let session = RecoveryCodeSession(transport: transport, host: host)
        session.start()
        return session
    }

    private func model(_ session: RecoveryCodeSession) -> RecoveryCodeChallengeModel? {
        session.model as? RecoveryCodeChallengeModel
    }

    @Test func itStartsOnTheField_withNothingSent() {
        let transport = ScriptedRecoveryCodeTransport()
        let sut = session(transport)
        #expect(model(sut)?.newCode == nil)
        #expect(model(sut)?.isVerifying == false)
        #expect(transport.log.isEmpty, "nothing is sent until the user submits")
    }

    @Test func aWrongCode_staysOnTheField_thenTheRightOneShowsTheNewCode() async {
        let transport = ScriptedRecoveryCodeTransport(verify: [.success(.rejected), .success(.rotated(newCode: "NEW"))])
        let sut = session(transport)

        model(sut)?.submit("BAD")
        #expect(model(sut)?.isVerifying == true)
        await eventually { model(sut)?.isCodeRejected == true }
        #expect(host.events.isEmpty)

        model(sut)?.submit(" GOOD ")
        await eventually { model(sut)?.newCode == "NEW" }
        #expect(transport.log == ["verify BAD", "verify GOOD"])
        #expect(host.events.isEmpty, "not signed in until the new code is confirmed")
    }

    @Test func confirmingTheNewCode_signsIn() async {
        let transport = ScriptedRecoveryCodeTransport()
        let sut = session(transport)
        model(sut)?.submit("OLD")
        await eventually { model(sut)?.newCode != nil }

        model(sut)?.confirm()
        await eventually { host.events == ["completed"] }
        #expect(transport.log == ["verify OLD", "confirm"])
        #expect(model(sut)?.newCode == nil, "nothing keeps the code once it is done")
    }

    @Test func aDroppedConnection_keepsTheScreen_andCanBeTriedAgain() async {
        let transport = ScriptedRecoveryCodeTransport(
            verify: [.failure(.network), .success(.rotated(newCode: "NEW"))], confirm: [.failure(.network)])
        let sut = session(transport)

        model(sut)?.submit("OLD")
        await eventually { model(sut)?.requestError == .network }
        model(sut)?.submit("OLD")
        await eventually { model(sut)?.newCode == "NEW" }

        model(sut)?.confirm()
        await eventually { model(sut)?.requestError == .network }
        #expect(model(sut)?.newCode == "NEW", "the new code is still on screen")
        #expect(host.events.isEmpty)
    }

    @Test func anotherFactor_isPassedOn() async {
        let next = [scriptedOffer("push:0", factor: .push, label: "iPhone")]
        let sut = session(ScriptedRecoveryCodeTransport(confirm: [.success(.anotherFactor(next))]))
        model(sut)?.submit("OLD")
        await eventually { model(sut)?.newCode != nil }
        model(sut)?.confirm()
        await eventually { host.events == ["menu"] }
        #expect(host.offers == [next])
    }

    @Test func aFailure_isReported() async {
        let sut = session(ScriptedRecoveryCodeTransport(verify: [.failure(.tooManyAttempts)]))
        model(sut)?.submit("OLD")
        await eventually { host.events == ["failed"] }
        #expect(host.errors == [.tooManyAttempts])
    }

    /// The user left before the request ran: it would use the code up with nobody to show the new one to.
    @Test func aCheckThatNobodyWantsAnyMore_isNeverSent() async {
        let transport = ScriptedRecoveryCodeTransport()
        let sut = session(transport)
        model(sut)?.submit("OLD")
        sut.deactivate()
        await settle()
        #expect(transport.log.isEmpty)
    }

    @Test func switchAndCancel_goToTheCore() {
        host.canSwitch = true
        let sut = session(ScriptedRecoveryCodeTransport())
        #expect(model(sut)?.canSwitch == true)
        model(sut)?.switchFactor()
        model(sut)?.cancel()
        #expect(host.events == ["switch", "cancel"])
    }

    @Test func afterTheFlowEnds_nothingMoreIsSentOrReported() async {
        let transport = ScriptedRecoveryCodeTransport()
        let sut = session(transport)
        let stale = model(sut)
        await sut.cancelAndWait()
        stale?.submit("OLD")
        await settle()
        #expect(transport.log.isEmpty)
        #expect(host.events.isEmpty)
    }
}
