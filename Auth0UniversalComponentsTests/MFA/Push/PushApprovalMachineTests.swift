@testable import Auth0UniversalComponents
import Testing

// swiftlint:disable line_length
// (Dense rule tables and regexes read better on one line; wrapping them hides the rule.)

@Suite
struct PushApprovalMachineTests {

    private let iPad = scriptedOffer("push:1", factor: .push, label: "iPad")

    private enum Step {
        case event(PushApprovalEvent)
        /// The answer to the push just sent / the check just sent, in the epoch in force.
        case sent(PushPending)
        case checked(PushCheck)
        case failed(MfaError)
        case pollDue
        /// The resend countdown moved on by this many seconds, in the epoch in force.
        case tick(Int)
        /// An answer to a request issued `behind` epochs ago.
        case lateCheck(PushCheck, behind: Int)
    }

    private func fold(_ steps: [Step], from state: PushApprovalState = PushApprovalState(),
                      policy: PushPollingPolicy = .default) -> (state: PushApprovalState, effects: [PushApprovalEffect]) {
        var current = state
        var all: [PushApprovalEffect] = []
        for step in steps {
            let event: PushApprovalEvent
            switch step {
            case let .event(value): event = value
            case let .sent(pending): event = .sent(pending, epoch: current.epoch)
            case let .checked(check): event = .checked(check, epoch: current.epoch)
            case let .failed(error): event = .failed(error, epoch: current.epoch)
            case .pollDue: event = .pollDue(epoch: current.epoch)
            case let .tick(seconds): event = .cooldownTick(seconds: seconds, epoch: current.epoch)
            case let .lateCheck(check, behind): event = .checked(check, epoch: current.epoch - behind)
            }
            let (next, effects) = PushApprovalMachine.reduce(current, event, policy: policy)
            current = next
            all += effects
        }
        return (current, all)
    }

    /// Resend allowed as soon as the push is out, for the tests that are not about the countdown.
    private let noCooldown = PushPollingPolicy(resendCooldownSeconds: 0)

    private let pending = PushPending(retryAfterMs: 2_000, canResend: true)
    /// Pushed and waiting, with the timer running.
    private var waiting: [Step] { [.event(.start), .sent(pending)] }

    // MARK: Sending

    @Test func start_sendsThePush() {
        let (state, effects) = fold([.event(.start)])
        #expect(state.phase == .sending)
        #expect(effects == [.send(epoch: 1)])
    }

    @Test func aSentPush_startsTheTimer_atTheServersInterval_clamped() {
        let (state, effects) = fold([.event(.start), .sent(PushPending(retryAfterMs: 500, canResend: false))])
        #expect(state.phase == .waiting)
        #expect(state.intervalMs == 1_000)
        #expect(effects.contains(.schedulePoll(afterMs: 1_000, epoch: 1)))
        #expect(fold([.event(.start), .sent(PushPending(retryAfterMs: 600_000, canResend: false))]).state.intervalMs == 60_000)
        #expect(fold([.event(.start), .sent(PushPending(retryAfterMs: nil, canResend: false))]).state.intervalMs == 2_000)
    }

    @Test func aSendThatFails_endsTheFlow() {
        let (state, effects) = fold([.event(.start), .failed(.network)])
        #expect(state.phase == .finished)
        #expect(effects.last == .report(.failed(.network)))
    }

    // MARK: Polling

    @Test func thePollTimer_sendsOneCheck_andNotASecondWhileItIsInFlight() {
        let (state, effects) = fold(waiting + [.pollDue])
        #expect(state.checkInFlight)
        #expect(effects.last == .check(epoch: 1))
        #expect(fold([.pollDue], from: state).effects.isEmpty)
    }

    @Test func pending_schedulesTheNextCheck_atTheServersInterval() {
        let (state, effects) = fold(waiting + [.pollDue, .checked(.pending(retryAfterMs: 3_000))])
        #expect(state.intervalMs == 3_000)
        #expect(!state.checkInFlight)
        #expect(effects.last == .schedulePoll(afterMs: 3_000, epoch: 1))
    }

    @Test func slowDown_addsTwoSeconds_atLeast() {
        let (state, effects) = fold(waiting + [.pollDue, .checked(.slowDown(retryAfterMs: nil))])
        #expect(state.intervalMs == 4_000)
        #expect(effects.last == .schedulePoll(afterMs: 4_000, epoch: 1))
        #expect(fold(waiting + [.pollDue, .checked(.slowDown(retryAfterMs: 9_000))]).state.intervalMs == 9_000)
    }

    @Test func approval_reportsCompleted_once() {
        let (state, effects) = fold(waiting + [.pollDue, .checked(.approved), .checked(.approved)])
        #expect(state.phase == .finished)
        #expect(effects.filter { $0 == .report(.completed) }.count == 1)
    }

    @Test func approvalThatAsksForAnotherFactor_reportsTheMenu() {
        let (state, effects) = fold(waiting + [.pollDue, .checked(.anotherFactor([iPad]))])
        #expect(state.phase == .finished)
        #expect(effects.last == .report(.anotherFactor([iPad])))
    }

    // MARK: Network failures

    private func failures(_ count: Int, then: [Step] = []) -> [Step] {
        (0..<count).flatMap { _ in [Step.pollDue, .failed(.network)] } + then
    }

    @Test func threeNetworkFailures_areTolerated_theFourthEndsTheFlow() {
        #expect(fold(waiting + failures(3)).state.phase == .waiting)
        let (state, effects) = fold(waiting + failures(4))
        #expect(state.phase == .finished)
        #expect(effects.last == .report(.failed(.network)))
    }

    @Test func networkFailuresInTheBackground_dontCount() {
        let (state, _) = fold(waiting + [.event(.appBecameInactive)] + failures(6))
        #expect(state.phase == .waiting)
        #expect(state.networkFailures == 0)
    }

    @Test func backInTheForeground_theCountResumes() {
        // The foreground check was in flight, so its failure counts as the first; three more reach the limit.
        let steps = waiting + [.event(.appBecameInactive)] + failures(5) + [.event(.appBecameActive), .failed(.network)] + failures(3)
        #expect(fold(steps).state.phase == .finished)
    }

    @Test func anyOtherFailure_endsTheFlowAtOnce() {
        let (state, effects) = fold(waiting + [.pollDue, .failed(.rejected)])
        #expect(state.phase == .finished)
        #expect(effects.last == .report(.failed(.rejected)))
    }

    // MARK: Foreground

    @Test func comingBackToTheForeground_checksAtOnce_andNotAgainWhileInFlight() {
        let (state, effects) = fold(waiting + [.event(.appBecameActive)])
        #expect(state.checkInFlight)
        #expect(effects.suffix(2) == [.cancelPoll, .check(epoch: 1)])
        #expect(fold([.event(.appBecameActive)], from: state).effects.isEmpty)
    }

    @Test func foregroundBeforeThePushIsSent_checksNothing() {
        #expect(fold([.event(.start), .event(.appBecameActive)]).effects == [.send(epoch: 1)])
    }

    // MARK: Resend

    @Test func resend_sendsAgain_inANewEpoch() {
        let (state, effects) = fold(waiting + [.event(.resend)], policy: noCooldown)
        #expect(state.phase == .sending)
        #expect(state.epoch == 2)
        #expect(effects.suffix(2) == [.cancelPoll, .send(epoch: 2)])
    }

    @Test func resend_isIgnored_whenTheServerDoesNotOfferIt() {
        let steps: [Step] = [.event(.start), .sent(PushPending(retryAfterMs: 2_000, canResend: false)), .event(.resend)]
        #expect(fold(steps).state.epoch == 1)
    }

    @Test func anAnswerToAReplacedPush_isIgnored_butAnApprovalOnItsWayStillCounts() {
        let resent = waiting + [.pollDue, .event(.resend)]
        #expect(fold(resent + [.lateCheck(.pending(retryAfterMs: nil), behind: 1)], policy: noCooldown).effects.last == .send(epoch: 2))
        let (state, effects) = fold(resent + [.lateCheck(.approved, behind: 1)])
        #expect(state.phase == .finished)
        #expect(effects.last == .report(.completed))
    }

    // MARK: Leaving

    @Test func deactivated_noTimerAndNoNewChecks() {
        let (state, effects) = fold(waiting + [.event(.deactivate)])
        #expect(effects.last == .cancelPoll)
        #expect(fold([.pollDue, .event(.appBecameActive), .event(.resend)], from: state).effects.isEmpty)
    }

    @Test func deactivated_aCheckOnTheWire_stillReportsAnApproval() {
        let (state, _) = fold(waiting + [.pollDue, .event(.deactivate)])
        let (done, effects) = fold([.checked(.approved)], from: state)
        #expect(done.phase == .finished)
        #expect(effects.last == .report(.completed))
    }

    @Test func deactivated_aPendingAnswer_schedulesNothing() {
        let (state, _) = fold(waiting + [.pollDue, .event(.deactivate)])
        #expect(fold([.checked(.pending(retryAfterMs: nil))], from: state).effects.isEmpty)
    }

    /// Approved, and the policy wants another factor, after the user switched away: the server has moved to the next
    /// round, so this must be reported like a plain approval. Dropping it would leave the flow a round behind.
    @Test func deactivated_aCheckOnTheWire_stillReportsTheNextMenu() {
        let (state, _) = fold(waiting + [.pollDue, .event(.deactivate)])
        let (done, effects) = fold([.checked(.anotherFactor([iPad]))], from: state)
        #expect(done.phase == .finished)
        #expect(effects.last == .report(.anotherFactor([iPad])))
    }

    @Test func aMenuToAReplacedPush_stillCounts() {
        let resent = waiting + [.pollDue, .event(.resend)]
        #expect(fold(resent + [.lateCheck(.anotherFactor([iPad]), behind: 1)]).effects.last
                    == .report(.anotherFactor([iPad])))
    }

    // MARK: Resend cooldown

    @Test func aSentPush_startsTheResendCountdown() {
        let (state, effects) = fold(waiting)
        #expect(state.resendAvailableIn == 60)
        #expect(effects.contains(.scheduleCooldownTick(afterMs: 1_000, epoch: 1)))
        #expect(effects.contains(.schedulePoll(afterMs: 2_000, epoch: 1)), "the poll timer is unaffected")
    }

    @Test func aZeroCooldown_startsNoCountdown() {
        let (state, effects) = fold(waiting, policy: noCooldown)
        #expect(state.resendAvailableIn == 0)
        #expect(!effects.contains(where: { if case .scheduleCooldownTick = $0 { return true } else { return false } }))
    }

    @Test func eachTick_lowersTheCountdown_andAsksForTheNext() {
        let (state, effects) = fold(waiting + [.tick(1)])
        #expect(state.resendAvailableIn == 59)
        #expect(effects.last == .scheduleCooldownTick(afterMs: 1_000, epoch: 1))
    }

    @Test func aTickThatCoversSeveralSeconds_catchesUp_andStopsAtZero() {
        #expect(fold(waiting + [.tick(45)]).state.resendAvailableIn == 15, "an app that was suspended catches up")
        let (state, effects) = PushApprovalMachine.reduce(fold(waiting + [.tick(45)]).state,
                                                          .cooldownTick(seconds: 100, epoch: 1))
        #expect(state.resendAvailableIn == 0, "never below zero")
        #expect(effects.isEmpty, "and nothing more is scheduled")
    }

    @Test func aTickOfZeroSeconds_stillMovesItOneForward() {
        #expect(fold(waiting + [.tick(0)]).state.resendAvailableIn == 59)
    }

    @Test func resend_isIgnoredWhileCountingDown_andAcceptedAtZero() {
        let counting = fold(waiting + [.tick(59), .event(.resend)]).state
        #expect(counting.epoch == 1, "one second left: still ignored")
        #expect(counting.phase == .waiting)
        let ready = fold(waiting + [.tick(60), .event(.resend)])
        #expect(ready.state.epoch == 2)
        #expect(ready.effects.suffix(2) == [.cancelPoll, .send(epoch: 2)])
    }

    @Test func aResend_startsTheCountdownAgain_whenItsPushIsSent() {
        let policy = PushPollingPolicy(resendCooldownSeconds: 5)
        let resent = fold(waiting + [.tick(5), .event(.resend)], policy: policy).state
        #expect(resent.resendAvailableIn == 0, "while the new push goes out there is nothing to count")
        #expect(fold([.sent(pending)], from: resent, policy: policy).state.resendAvailableIn == 5)
    }

    @Test func aTickOfAReplacedPush_isIgnored() {
        let policy = PushPollingPolicy(resendCooldownSeconds: 5)
        let resent = fold(waiting + [.tick(5), .event(.resend), .sent(pending)], policy: policy).state
        #expect(resent.epoch == 2)
        let (after, effects) = PushApprovalMachine.reduce(resent, .cooldownTick(seconds: 1, epoch: 1), policy: policy)
        #expect(after == resent)
        #expect(effects.isEmpty)
    }

    @Test func deactivated_theCountdownStops() {
        let deactivated = fold(waiting + [.event(.deactivate)]).state
        let (after, effects) = PushApprovalMachine.reduce(deactivated, .cooldownTick(seconds: 1, epoch: 1))
        #expect(after == deactivated)
        #expect(effects.isEmpty)
    }

    @Test func aFinishedPush_hasNoCountdown() {
        #expect(fold(waiting + [.pollDue, .checked(.approved)]).state.resendAvailableIn == 0)
    }

    // MARK: Resend offered or withdrawn

    @Test func everyAnswer_updatesWhetherThePushCanBeResent() {
        let offered: [Step] = [.event(.start), .sent(PushPending(retryAfterMs: 2_000, canResend: true))]
        #expect(fold(offered).state.canResend)
        let withdrawn = fold(offered + [.pollDue, .checked(.pending(retryAfterMs: nil, canResend: false))]).state
        #expect(!withdrawn.canResend, "the server stopped offering the push")
        #expect(fold([.event(.resend)], from: withdrawn, policy: noCooldown).state.epoch == 1, "so resend does nothing")
        let slowed = fold(offered + [.pollDue, .checked(.slowDown(retryAfterMs: nil, canResend: false))]).state
        #expect(!slowed.canResend)
        let unsaid = fold(offered + [.pollDue, .checked(.pending(retryAfterMs: nil))]).state
        #expect(unsaid.canResend, "an answer that doesn't say keeps what the last one said")
    }
}

// swiftlint:enable line_length
