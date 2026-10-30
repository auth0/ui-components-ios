import Foundation

/// How often the push factor checks for approval.
struct PushPollingPolicy: Sendable {
    /// Bounds applied to the server's interval, in milliseconds.
    var range = 1_000...60_000
    /// The interval when the server doesn't give one.
    var defaultInterval = 2_000
    /// How much longer each wait gets after `slowDown`.
    var slowDownStep = 2_000
    /// Consecutive network failures tolerated while waiting for an approval.
    var maxNetworkFailures = 3

    static let `default` = PushPollingPolicy()

    func clamp(_ milliseconds: Int) -> Int {
        min(max(milliseconds, range.lowerBound), range.upperBound)
    }
}

struct PushApprovalState: Equatable {
    enum Phase: Equatable { case sending, waiting, finished }

    var phase = Phase.sending
    /// Bumped on every send. A reply carries the epoch it was issued in, so an answer to a push the user replaced
    /// (by resending) can be recognised and dropped. The checks of one push share an epoch.
    var epoch = 0
    var canResend = false
    var intervalMs = 2_000
    var networkFailures = 0
    /// A check has been sent and not yet answered.
    var checkInFlight = false
    /// False while the app is in the background. Network failures then aren't held against the push: approving in
    /// another app suspends this one mid-check.
    var isAppActive = true
    /// False once the user moved to another factor: no timers, no new requests.
    var isActive = true
}

enum PushApprovalEvent: Equatable {
    case start
    case sent(PushPending, epoch: Int)
    case checked(PushCheck, epoch: Int)
    case failed(MfaError, epoch: Int)
    /// The wait between two checks is over.
    case pollDue(epoch: Int)
    case resend
    case appBecameActive
    case appBecameInactive
    case deactivate
}

enum PushApprovalReport: Equatable {
    case completed
    case anotherFactor([MfaFactorOffer])
    case failed(MfaError)
}

enum PushApprovalEffect: Equatable {
    case send(epoch: Int)
    case schedulePoll(afterMs: Int, epoch: Int)
    case check(epoch: Int)
    case cancelPoll
    case report(PushApprovalReport)
}

/// Every decision the push factor makes. Pure: no UI, no network, no clock.
enum PushApprovalMachine {
    static func reduce(_ old: PushApprovalState, _ event: PushApprovalEvent,
                       policy: PushPollingPolicy = .default) -> (PushApprovalState, [PushApprovalEffect]) {
        var state = old
        let effects = state.apply(event, policy: policy)
        return (state, effects)
    }
}

// swiftlint:disable cyclomatic_complexity

extension PushApprovalState {
    fileprivate mutating func apply(_ event: PushApprovalEvent, policy: PushPollingPolicy) -> [PushApprovalEffect] {
        switch event {
        case .start:
            guard epoch == 0, isActive else { return [] }
            epoch = 1
            return [.send(epoch: epoch)]
        case let .sent(pending, epoch):
            return sent(pending, epoch: epoch, policy: policy)
        case let .checked(check, epoch):
            return checked(check, epoch: epoch, policy: policy)
        case let .failed(error, epoch):
            return failed(error, epoch: epoch, policy: policy)
        case let .pollDue(epoch):
            guard phase == .waiting, epoch == self.epoch, !checkInFlight, isActive else { return [] }
            checkInFlight = true
            return [.check(epoch: self.epoch)]
        case .resend:
            guard phase == .waiting, canResend, isActive else { return [] }
            epoch += 1
            phase = .sending
            canResend = false
            checkInFlight = false
            return [.cancelPoll, .send(epoch: epoch)]
        case .appBecameActive:
            // The user may have approved while the app was away: check now instead of waiting out the interval.
            isAppActive = true
            guard phase == .waiting, !checkInFlight, isActive else { return [] }
            checkInFlight = true
            return [.cancelPoll, .check(epoch: epoch)]
        case .appBecameInactive:
            isAppActive = false
            return []
        case .deactivate:
            isActive = false
            return [.cancelPoll]
        }
    }

    private mutating func sent(_ pending: PushPending, epoch: Int, policy: PushPollingPolicy) -> [PushApprovalEffect] {
        // `epoch` is 0 until the first push is sent: an answer before that answers nothing.
        guard phase == .sending, epoch == self.epoch, epoch > 0 else { return [] }
        phase = .waiting
        canResend = pending.canResend
        networkFailures = 0
        checkInFlight = false
        intervalMs = policy.clamp(pending.retryAfterMs ?? policy.defaultInterval)
        return isActive ? [.schedulePoll(afterMs: intervalMs, epoch: self.epoch)] : []
    }

    private mutating func checked(_ check: PushCheck, epoch: Int, policy: PushPollingPolicy) -> [PushApprovalEffect] {
        guard phase != .finished else { return [] }
        // A verified answer already on its way still counts, whatever the user did since: the server has moved on.
        switch check {
        case .approved:
            finish()
            return [.cancelPoll, .report(.completed)]
        case let .anotherFactor(offers):
            finish()
            return [.cancelPoll, .report(.anotherFactor(offers))]
        case .pending, .slowDown:
            break
        }
        guard phase == .waiting, epoch == self.epoch, checkInFlight else { return [] }
        checkInFlight = false
        switch check {
        case .approved, .anotherFactor:
            return []
        case let .pending(milliseconds, canResend):
            networkFailures = 0
            intervalMs = policy.clamp(milliseconds ?? intervalMs)
            if let canResend { self.canResend = canResend }
        case let .slowDown(milliseconds, canResend):
            intervalMs = policy.clamp(max(milliseconds ?? 0, intervalMs + policy.slowDownStep))
            if let canResend { self.canResend = canResend }
        }
        return isActive ? [.schedulePoll(afterMs: intervalMs, epoch: self.epoch)] : []
    }

    private mutating func failed(_ error: MfaError, epoch: Int, policy: PushPollingPolicy) -> [PushApprovalEffect] {
        guard phase != .finished, epoch == self.epoch else { return [] }
        // A flaky network while waiting is retried a few times first. Failures while the app is in the background
        // don't count: approving in another app suspends this one mid-check.
        let tolerated = networkFailures < policy.maxNetworkFailures || !isAppActive
        if phase == .waiting, checkInFlight, error == .network, tolerated {
            if isAppActive { networkFailures += 1 }
            checkInFlight = false
            return isActive ? [.schedulePoll(afterMs: intervalMs, epoch: self.epoch)] : []
        }
        finish()
        return [.cancelPoll, .report(.failed(error))]
    }

    /// Nothing more is sent, checked or offered.
    private mutating func finish() {
        phase = .finished
        checkInFlight = false
        canResend = false
    }
}

// swiftlint:enable cyclomatic_complexity
