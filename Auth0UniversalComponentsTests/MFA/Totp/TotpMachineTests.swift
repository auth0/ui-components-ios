@testable import Auth0UniversalComponents
import Testing

/// Every decision the authenticator app factor makes, with no UI, network or clock.
@Suite
struct TotpMachineTests {

    private func run(_ events: [TotpEvent], from state: TotpState = TotpState()) -> (TotpState, [TotpEffect]) {
        events.reduce((state, [])) { current, event in
            let (next, effects) = TotpMachine.reduce(current.0, event)
            return (next, current.1 + effects)
        }
    }

    private var awaiting: TotpState { run([.start]).0 }

    @Test func start_showsTheCodeScreen_withNothingToSend() {
        let (state, effects) = run([.start])
        #expect(state.phase == .awaitingCode)
        #expect(effects.isEmpty, "the app makes the code, so nothing goes to the server first")
    }

    @Test func start_afterTheUserLeft_doesNothing() {
        let (state, _) = run([.deactivate, .start])
        #expect(state.phase == .idle)
    }

    // MARK: Submitting

    @Test func aCompleteCode_isChecked() {
        let (state, effects) = run([.submit(code: "123456")], from: awaiting)
        #expect(state.phase == .verifying)
        #expect(effects == [.verify(code: "123456")])
    }

    @Test(arguments: ["", "12345", "1234567", "12345a", "١٢٣٤٥٦", "12 456"])
    func aCodeThatIsNotSixDigits_isIgnored(_ code: String) {
        let (state, effects) = run([.submit(code: code)], from: awaiting)
        #expect(state.phase == .awaitingCode)
        #expect(effects.isEmpty)
    }

    @Test func aCodeBeforeTheScreenIsUp_isIgnored() {
        #expect(run([.submit(code: "123456")]).1.isEmpty)
    }

    @Test func oneCheckAtATime() {
        let (_, effects) = run([.submit(code: "123456"), .submit(code: "654321")], from: awaiting)
        #expect(effects == [.verify(code: "123456")])
    }

    @Test func afterTheUserMovedOn_noNewCodeIsChecked() {
        #expect(run([.deactivate, .submit(code: "123456")], from: awaiting).1.isEmpty)
    }

    // MARK: Answers

    @Test func anAcceptedCode_completes() {
        let (state, effects) = run([.submit(code: "123456"), .verified(.verified)], from: awaiting)
        #expect(state.phase == .finished)
        #expect(effects.last == .report(.completed))
    }

    @Test func anAcceptedCode_stillCompletes_afterTheUserMovedOn() {
        let (_, effects) = run([.submit(code: "123456"), .deactivate, .verified(.verified)], from: awaiting)
        #expect(effects.last == .report(.completed), "the server has moved on")
    }

    @Test func anAcceptedCode_thatAsksForAnotherFactor_reportsTheMenu() {
        let next = [MfaFactorOffer(id: "push:0", factor: .push, label: "iPhone", reference: 0)]
        let (state, effects) = run([.submit(code: "123456"), .verified(.anotherFactor(next))], from: awaiting)
        #expect(state.phase == .finished)
        #expect(effects.last == .report(.anotherFactor(next)))
    }

    @Test func aWrongCode_staysOnTheScreen_andAnotherCanBeTried() {
        let (rejected, effects) = run([.submit(code: "000000"), .verified(.rejected)], from: awaiting)
        #expect(rejected.phase == .awaitingCode)
        #expect(rejected.isCodeRejected)
        #expect(effects == [.verify(code: "000000")], "nothing more is reported")

        let (retry, retryEffects) = run([.submit(code: "123456")], from: rejected)
        #expect(retry.phase == .verifying)
        #expect(!retry.isCodeRejected, "the message goes with the new check")
        #expect(retryEffects == [.verify(code: "123456")])
    }

    @Test func aDroppedConnection_keepsTheScreen_andTheSameStepCanBeTriedAgain() {
        let (dropped, effects) = run([.submit(code: "123456"), .verifyFailed(.network)], from: awaiting)
        #expect(dropped.phase == .awaitingCode)
        #expect(dropped.requestError == .network)
        #expect(effects == [.verify(code: "123456")])

        let (retry, _) = run([.submit(code: "123456")], from: dropped)
        #expect(retry.phase == .verifying)
        #expect(retry.requestError == nil, "cleared when the next check starts")
    }

    @Test(arguments: [MfaError.tooManyAttempts, .tokenExpired, .unexpected(nil)])
    func anyOtherFailure_endsTheFactor(_ error: MfaError) {
        let (state, effects) = run([.submit(code: "123456"), .verifyFailed(error)], from: awaiting)
        #expect(state.phase == .finished)
        #expect(effects.last == .report(.failed(error)))
    }

    @Test func anAnswerWithNothingBeingChecked_isIgnored() {
        #expect(run([.verified(.verified), .verifyFailed(.tooManyAttempts)], from: awaiting).1.isEmpty)
    }
}
