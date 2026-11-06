@testable import Auth0UniversalComponents
import Testing

/// Every decision of the SMS factor, with no UI, network or clock.
@Suite
struct PhoneCodeMachineTests {

    private let policy = PhoneCodePolicy(codeLength: 6, resendCooldownSeconds: 60)
    private let noWait = PhoneCodePolicy(codeLength: 6, resendCooldownSeconds: 0)

    private func run(_ events: [PhoneCodeEvent], from state: PhoneCodeState = PhoneCodeState(),
                     policy: PhoneCodePolicy? = nil) -> (PhoneCodeState, [PhoneCodeEffect]) {
        var state = state
        var effects: [PhoneCodeEffect] = []
        for event in events {
            let (next, new) = PhoneCodeMachine.reduce(state, event, policy: policy ?? self.policy)
            state = next
            effects = new
        }
        return (state, effects)
    }

    /// Sent and waiting for the code, after the first send.
    private var awaitingCode: PhoneCodeState {
        run([.start, .sent(PhoneCodeSent(canResend: true), epoch: 1)], policy: noWait).0
    }

    // MARK: Sending

    @Test func start_sendsOnce() {
        let (state, effects) = run([.start])
        #expect(effects == [.send(epoch: 1)])
        #expect(state.phase == .sending)
        #expect(run([.start, .start]).1.isEmpty, "a second start sends nothing")
    }

    @Test func sent_waitsForTheCode_andStartsTheResendWait() {
        let (state, effects) = run([.start, .sent(PhoneCodeSent(canResend: true), epoch: 1)])
        #expect(state.phase == .awaitingCode)
        #expect(state.canResend)
        #expect(state.resendAvailableIn == 60)
        #expect(effects == [.scheduleCooldownTick(afterMs: 1_000, epoch: 1)])
    }

    @Test func anAnswerForAnotherSend_isDropped() {
        #expect(run([.start, .sent(PhoneCodeSent(canResend: true), epoch: 7)]).0.phase == .sending)
    }

    // MARK: Checking the code

    @Test func aCompleteCode_isChecked() {
        let (state, effects) = run([.submit(code: "123456")], from: awaitingCode)
        #expect(state.phase == .verifying)
        #expect(effects == [.verify(code: "123456", epoch: 1)])
    }

    @Test(arguments: ["12345", "1234567", "12345a", "١٢٣٤٥٦", ""])
    func anIncompleteOrOddCode_isIgnored(_ code: String) {
        let (state, effects) = run([.submit(code: code)], from: awaitingCode)
        #expect(state.phase == .awaitingCode)
        #expect(effects.isEmpty)
    }

    @Test func aSecondSubmitWhileChecking_isIgnored() {
        let (_, effects) = run([.submit(code: "123456"), .submit(code: "654321")], from: awaitingCode)
        #expect(effects.isEmpty)
    }

    @Test func aWrongCode_staysForAnotherTry() {
        let (state, effects) = run([.submit(code: "000000"), .verified(.rejected(canResend: true), epoch: 1)],
                                   from: awaitingCode)
        #expect(state.phase == .awaitingCode)
        #expect(state.isCodeRejected)
        #expect(effects.isEmpty)
        // The next code clears the rejection while it is checked.
        #expect(run([.submit(code: "123456")], from: state).0.isCodeRejected == false)
    }

    @Test func aWrongCode_canEndTheResend() {
        let (state, _) = run([.submit(code: "000000"), .verified(.rejected(canResend: false), epoch: 1)],
                             from: awaitingCode)
        #expect(state.canResend == false)
    }

    @Test func theRightCode_signsIn() {
        let (state, effects) = run([.submit(code: "123456"), .verified(.verified, epoch: 1)], from: awaitingCode)
        #expect(state.phase == .finished)
        #expect(effects == [.report(.completed)])
    }

    @Test func theRightCode_canLeadToAnotherFactor() {
        let next = [MfaFactorOffer(id: "push:0", factor: .push, label: "iPhone", reference: 0)]
        let (_, effects) = run([.submit(code: "123456"), .verified(.anotherFactor(next), epoch: 1)],
                               from: awaitingCode)
        #expect(effects == [.report(.anotherFactor(next))])
    }

    @Test func aVerdictWithoutACheck_isDropped() {
        #expect(run([.verified(.verified, epoch: 1)], from: awaitingCode).1.isEmpty)
    }

    // MARK: Failures

    @Test func aFailure_endsTheFactor() {
        let (state, effects) = run([.submit(code: "123456"), .failed(.tooManyAttempts, epoch: 1)], from: awaitingCode)
        #expect(state.phase == .finished)
        #expect(effects == [.report(.failed(.tooManyAttempts))])
    }

    @Test func aFailureOfAReplacedSend_isDropped() {
        let (state, effects) = run([.resend, .failed(.network, epoch: 1)], from: awaitingCode)
        #expect(state.phase == .sending)
        #expect(effects.isEmpty)
    }

    // MARK: Resend

    @Test func resend_waitsForTheCountdown() {
        let waiting = run([.start, .sent(PhoneCodeSent(canResend: true), epoch: 1)]).0
        #expect(run([.resend], from: waiting).1.isEmpty, "still counting down")
    }

    @Test func resend_sendsANewCode_andClearsARejection() {
        let rejected = run([.submit(code: "000000"), .verified(.rejected(canResend: true), epoch: 1)],
                           from: awaitingCode).0
        let (state, effects) = run([.resend], from: rejected)
        #expect(effects == [.send(epoch: 2)])
        #expect(state.phase == .sending)
        #expect(state.isCodeRejected == false)
    }

    @Test func resend_needsTheServersOffer() {
        let noResend = run([.start, .sent(PhoneCodeSent(canResend: false), epoch: 1)], policy: noWait).0
        #expect(run([.resend], from: noResend).1.isEmpty)
    }

    @Test func theCountdown_ticksDown_andCatchesUp() {
        let waiting = run([.start, .sent(PhoneCodeSent(canResend: true), epoch: 1)]).0
        let (oneLater, effects) = run([.cooldownTick(seconds: 1, epoch: 1)], from: waiting)
        #expect(oneLater.resendAvailableIn == 59)
        #expect(effects == [.scheduleCooldownTick(afterMs: 1_000, epoch: 1)])
        // Back from the background: the seconds that passed come off at once.
        #expect(run([.cooldownTick(seconds: 90, epoch: 1)], from: waiting).0.resendAvailableIn == 0)
    }

    @Test func aTickOfAReplacedCode_isDropped() {
        let waiting = run([.start, .sent(PhoneCodeSent(canResend: true), epoch: 1)]).0
        #expect(run([.cooldownTick(seconds: 1, epoch: 5)], from: waiting).0.resendAvailableIn == 60)
    }

    // MARK: Moving to another factor

    @Test func afterTheUserLeft_nothingNewIsSent() {
        let left = run([.deactivate], from: awaitingCode).0
        #expect(run([.resend], from: left).1.isEmpty)
        #expect(run([.submit(code: "123456")], from: left).1.isEmpty)
    }

    /// A code already on its way still signs the user in: the server has moved on.
    @Test func aCodeCheckedBeforeTheUserLeft_stillSignsIn() {
        let checking = run([.submit(code: "123456")], from: awaitingCode).0
        let (_, effects) = run([.deactivate, .verified(.verified, epoch: 1)], from: checking)
        #expect(effects == [.report(.completed)])
    }
}
