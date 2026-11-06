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

    /// A first send that fails leaves nothing to stay on: the factor ends, whatever the reason.
    @Test(arguments: [MfaError.network, .tooManyAttempts, .tokenInvalid])
    func aFirstSendThatFails_endsTheFactor(_ error: MfaError) {
        let (state, effects) = run([.start, .sendFailed(error, epoch: 1)])
        #expect(state.phase == .finished)
        #expect(effects == [.report(.failed(error))])
    }

    /// The server locked the challenge after wrong codes: nothing on this screen can fix that.
    @Test func tooManyWrongCodes_endsTheFactor() {
        let (state, effects) = run([.submit(code: "123456"), .verifyFailed(.tooManyAttempts, epoch: 1)],
                                   from: awaitingCode)
        #expect(state.phase == .finished)
        #expect(effects == [.report(.failed(.tooManyAttempts))])
    }

    @Test(arguments: [MfaError.tokenInvalid, .unexpected(nil), .rejected])
    func aCheckThatFailsForAnyOtherReason_endsTheFactor(_ error: MfaError) {
        let (state, effects) = run([.submit(code: "123456"), .verifyFailed(error, epoch: 1)], from: awaitingCode)
        #expect(state.phase == .finished)
        #expect(effects == [.report(.failed(error))])
    }

    @Test func aFailureOfAReplacedSend_isDropped() {
        let (state, effects) = run([.resend, .sendFailed(.network, epoch: 1)], from: awaitingCode)
        #expect(state.phase == .sending)
        #expect(effects.isEmpty)
    }

    @Test func aFailureOfACheckThatIsNotRunning_isDropped() {
        let (state, effects) = run([.verifyFailed(.network, epoch: 1)], from: awaitingCode)
        #expect(state.phase == .awaitingCode)
        #expect(effects.isEmpty)
    }

    // MARK: A dropped connection

    @Test func aDroppedConnectionWhileChecking_keepsTheCode_andLetsTheSameOneBeSentAgain() {
        let (state, effects) = run([.submit(code: "123456"), .verifyFailed(.network, epoch: 1)], from: awaitingCode)
        #expect(state.phase == .awaitingCode)
        #expect(state.requestError == .network)
        #expect(state.isCodeRejected == false)
        #expect(effects.isEmpty, "nothing ends")
        // Submitting again clears the error while the code is checked.
        let (again, retry) = run([.submit(code: "123456")], from: state)
        #expect(again.requestError == nil)
        #expect(retry == [.verify(code: "123456", epoch: 1)])
    }

    @Test func aResendThatFails_keepsTheScreen_withTheCodeAlreadyOnThePhone() {
        let (state, effects) = run([.resend, .sendFailed(.network, epoch: 2)], from: awaitingCode, policy: policy)
        #expect(state.phase == .awaitingCode)
        #expect(state.hasCode)
        #expect(state.requestError == .network)
        #expect(state.canResend, "the user can try again")
        #expect(effects == [.scheduleCooldownTick(afterMs: 1_000, epoch: 2)])
        // The code on the phone is still good.
        #expect(run([.submit(code: "123456")], from: state).1 == [.verify(code: "123456", epoch: 2)])
    }

    @Test func aResendThatFails_waitsAgainBeforeTheNextTry() {
        let failed = run([.resend, .sendFailed(.network, epoch: 2)], from: awaitingCode, policy: policy).0
        #expect(failed.resendAvailableIn == 60)
        #expect(run([.resend], from: failed, policy: policy).1.isEmpty, "a refusal can't be hammered")
        let later = run([.cooldownTick(seconds: 60, epoch: 2)], from: failed, policy: policy).0
        #expect(run([.resend], from: later, policy: policy).1 == [.send(epoch: 3)])
    }

    @Test func aResendRefusedForTooManyRequests_keepsTheScreen() {
        let (state, _) = run([.resend, .sendFailed(.tooManyAttempts, epoch: 2)], from: awaitingCode)
        #expect(state.phase == .awaitingCode)
        #expect(state.requestError == .tooManyAttempts)
    }

    @Test func aResendThatFailsForAnyOtherReason_endsTheFactor() {
        let (state, effects) = run([.resend, .sendFailed(.tokenInvalid, epoch: 2)], from: awaitingCode)
        #expect(state.phase == .finished)
        #expect(effects == [.report(.failed(.tokenInvalid))])
    }

    @Test func aNewCodeThatArrives_clearsTheError() {
        let failed = run([.resend, .sendFailed(.network, epoch: 2)], from: awaitingCode, policy: noWait).0
        let (state, _) = run([.resend, .sent(PhoneCodeSent(canResend: true), epoch: 3)], from: failed, policy: noWait)
        #expect(state.requestError == nil)
    }

    // MARK: An expired code

    @Test func anExpiredCode_staysOnTheScreen_withVerifyOff_andResendAtOnce() {
        // The wait is still running when the server says the code timed out.
        let waiting = run([.start, .sent(PhoneCodeSent(canResend: true), epoch: 1)]).0
        #expect(waiting.resendAvailableIn == 60)
        let (state, effects) = run([.submit(code: "123456"), .verifyFailed(.tokenExpired, epoch: 1)], from: waiting)
        #expect(state.phase == .awaitingCode)
        #expect(state.isCodeExpired)
        #expect(state.resendAvailableIn == 0, "only a new code helps, so there is no wait")
        #expect(effects.isEmpty)
        #expect(run([.submit(code: "123456")], from: state).1.isEmpty, "checking is off until a new code arrives")
        #expect(run([.resend], from: state).1 == [.send(epoch: 2)])
    }

    @Test func aNewCode_endsTheExpiry() {
        let expired = run([.submit(code: "123456"), .verifyFailed(.tokenExpired, epoch: 1)], from: awaitingCode).0
        let (state, _) = run([.resend, .sent(PhoneCodeSent(canResend: true), epoch: 2)], from: expired)
        #expect(state.isCodeExpired == false)
        #expect(run([.submit(code: "123456")], from: state).1 == [.verify(code: "123456", epoch: 2)])
    }

    @Test func anExpiredCode_withNoWayToSendAnother_endsTheFactor() {
        let noResend = run([.start, .sent(PhoneCodeSent(canResend: false), epoch: 1)], policy: noWait).0
        let (state, effects) = run([.submit(code: "123456"), .verifyFailed(.tokenExpired, epoch: 1)], from: noResend)
        #expect(state.phase == .finished)
        #expect(effects == [.report(.failed(.tokenExpired))])
    }

    @Test func aResendThatFails_afterTheCodeExpired_isStillAvailableAtOnce() {
        let expired = run([.submit(code: "123456"), .verifyFailed(.tokenExpired, epoch: 1)], from: awaitingCode).0
        let (state, effects) = run([.resend, .sendFailed(.network, epoch: 2)], from: expired, policy: policy)
        #expect(state.isCodeExpired)
        #expect(state.resendAvailableIn == 0)
        #expect(effects.isEmpty)
        #expect(run([.resend], from: state, policy: policy).1 == [.send(epoch: 3)])
    }

    // MARK: Coming back to a code that was just sent

    @Test func resume_showsTheEarlierCode_andSendsNothing() {
        let (state, effects) = run([.resume(canResend: true, resendAvailableIn: 25)])
        #expect(state.phase == .awaitingCode)
        #expect(state.hasCode)
        #expect(state.canResend)
        #expect(state.resendAvailableIn == 25)
        #expect(effects == [.scheduleCooldownTick(afterMs: 1_000, epoch: 1)])
        #expect(run([.resend], from: state).1.isEmpty, "the wait carries over")
    }

    @Test func resume_remembersThatTheServerOfferedNoResend() {
        #expect(run([.resume(canResend: false, resendAvailableIn: 25)]).0.canResend == false)
    }

    @Test func resume_neverWaitsLongerThanThePolicy() {
        #expect(run([.resume(canResend: true, resendAvailableIn: 600)]).0.resendAvailableIn == 60)
    }

    @Test func resume_countsDown_thenAllowsAResend() {
        let resumed = run([.resume(canResend: true, resendAvailableIn: 2)]).0
        let later = run([.cooldownTick(seconds: 2, epoch: 1)], from: resumed).0
        #expect(run([.resend], from: later).1 == [.send(epoch: 2)])
    }

    @Test func resume_isOnlyForAFreshFactor() {
        #expect(run([.resume(canResend: true, resendAvailableIn: 25)], from: awaitingCode).1.isEmpty)
        #expect(run([.resume(canResend: true, resendAvailableIn: 25), .start]).1.isEmpty, "and it doesn't also send")
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
