@testable import Auth0UniversalComponents
import Testing

// swiftlint:disable line_length
// (Dense rule tables and regexes read better on one line; wrapping them hides the rule.)

/// Visits every state the push machine can reach, applies every kind of event (current and stale) to each, and checks
/// the rules a push must keep. A failure names the state and the event.
@Suite
struct PushApprovalSearchTests {

    private let other = scriptedOffer("push:9", factor: .push)

    private struct StateKey: Hashable {
        let phase: String
        let epoch: Int
        let canResend: Bool
        let interval: Int
        let failures: Int
        let inFlight: Bool
        let appActive: Bool
        let active: Bool

        init(_ state: PushApprovalState) {
            phase = "\(state.phase)"
            // Only "current or stale" matters, so every epoch after the second is alike; and the reducer treats every
            // interval above a few seconds alike (the 60 s clamp has its own test).
            epoch = min(state.epoch, 2)
            canResend = state.canResend
            interval = min(state.intervalMs, 8_000)
            failures = state.networkFailures
            inFlight = state.checkInFlight
            appActive = state.isAppActive
            active = state.isActive
        }
    }

    private func invariantViolations(_ state: PushApprovalState) -> [String] {
        var found: [String] = []
        if state.phase == .finished, state.checkInFlight { found.append("I1 finished with a check in flight") }
        if state.checkInFlight, state.phase != .waiting { found.append("I2 a check in flight outside waiting") }
        if state.canResend, state.phase != .waiting { found.append("I3 resend offered outside waiting") }
        if state.networkFailures > PushPollingPolicy.default.maxNetworkFailures { found.append("I4 failures beyond the allowance") }
        if state.phase == .waiting, state.epoch == 0 { found.append("I5 waiting before anything was sent") }
        return found
    }

    private func alphabet(_ state: PushApprovalState) -> [(label: String, event: PushApprovalEvent)] {
        var out: [(String, PushApprovalEvent)] = [
            ("start", .start), ("resend", .resend), ("foreground", .appBecameActive),
            ("background", .appBecameInactive), ("deactivate", .deactivate)
        ]
        let pendings = [PushPending(retryAfterMs: 2_000, canResend: true), PushPending(retryAfterMs: nil, canResend: false)]
        let checks: [PushCheck] = [.approved, .pending(retryAfterMs: nil), .slowDown(retryAfterMs: nil), .anotherFactor([other]),
                                   .pending(retryAfterMs: nil, canResend: true), .slowDown(retryAfterMs: nil, canResend: false)]
        for epoch in Set([state.epoch, state.epoch - 1]) {
            let stale = epoch == state.epoch ? "" : "stale "
            for pending in pendings { out.append((stale + "sent", .sent(pending, epoch: epoch))) }
            for check in checks { out.append((stale + "checked \(check)", .checked(check, epoch: epoch))) }
            for error in [MfaError.network, .rejected] { out.append((stale + "failed \(error)", .failed(error, epoch: epoch))) }
            out.append((stale + "pollDue", .pollDue(epoch: epoch)))
        }
        return out
    }

    private func isReport(_ effect: PushApprovalEffect) -> Bool { if case .report = effect { return true } else { return false } }
    private func isCheck(_ effect: PushApprovalEffect) -> Bool { if case .check = effect { return true } else { return false } }
    private func isSend(_ effect: PushApprovalEffect) -> Bool { if case .send = effect { return true } else { return false } }
    private func isPoll(_ effect: PushApprovalEffect) -> Bool { if case .schedulePoll = effect { return true } else { return false } }

    private func transitionViolations(from old: PushApprovalState, to new: PushApprovalState,
                                      effects: [PushApprovalEffect], event: PushApprovalEvent, context: String) -> [String] {
        var found: [String] = []
        let reports = effects.filter(isReport).count
        // T1 a finished push stays finished and silent.
        if old.phase == .finished, new.phase != .finished || reports > 0 { found.append("T1 \(context): finished push moved or reported") }
        // T2 finishing reports exactly once; nothing else reports.
        if old.phase != .finished, new.phase == .finished, reports != 1 { found.append("T2 \(context): finished without exactly one report") }
        if new.phase != .finished, reports > 0 { found.append("T2 \(context): reported without finishing") }
        // T3 a check is never sent while another is in flight.
        if old.checkInFlight, effects.contains(where: isCheck), !isForeground(event) { found.append("T3 \(context): second check in flight") }
        // T4 a deactivated push starts nothing.
        if !old.isActive, effects.contains(where: { isCheck($0) || isSend($0) || isPoll($0) }) {
            found.append("T4 \(context): deactivated push started work")
        }
        // T5 leaving waiting always cancels the timer.
        if old.phase == .waiting, new.phase != .waiting, !effects.contains(.cancelPoll) { found.append("T5 \(context): left waiting without cancelPoll") }
        // T6 an answer to a replaced push changes nothing, except a verified answer already on its way.
        if isStale(event, in: old), !isApproval(event), old.phase != .finished, new != old || !effects.isEmpty {
            found.append("T6 \(context): stale answer had an effect")
        }
        return found
    }

    private func isForeground(_ event: PushApprovalEvent) -> Bool { event == .appBecameActive }

    /// Verified: approved, or approved and the policy wants another factor.
    private func isApproval(_ event: PushApprovalEvent) -> Bool {
        switch event {
        case .checked(.approved, _), .checked(.anotherFactor, _): return true
        default: return false
        }
    }

    private func isStale(_ event: PushApprovalEvent, in state: PushApprovalState) -> Bool {
        switch event {
        case let .sent(_, epoch), let .checked(_, epoch), let .failed(_, epoch), let .pollDue(epoch): return epoch != state.epoch
        default: return false
        }
    }

    @Test func everyReachableStateAndEvent_keepsTheRules() {
        var seen: Set<StateKey> = [StateKey(PushApprovalState())]
        var queue = [PushApprovalState()]
        var next = 0
        var violations: [String] = []

        while next < queue.count {
            let state = queue[next]
            next += 1
            violations += invariantViolations(state).map { "state \(StateKey(state)): \($0)" }
            for (label, event) in alphabet(state) {
                let (after, effects) = PushApprovalMachine.reduce(state, event)
                violations += transitionViolations(from: state, to: after, effects: effects, event: event,
                                                   context: "\(state.phase) + \(label)")
                if seen.insert(StateKey(after)).inserted { queue.append(after) }
            }
        }

        #expect(violations.isEmpty, "\(queue.count) states: \(violations.prefix(8))")
        #expect(queue.count > 100, "the search should reach the whole machine, reached \(queue.count)")
    }
}

// swiftlint:enable line_length
