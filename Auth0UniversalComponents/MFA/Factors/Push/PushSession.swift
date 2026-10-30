import Foundation

/// Runs one push from "send it" to "approved": the polling timer, one request at a time, resend, and the app going to
/// the background. It owns everything push-specific; the Core only hears the result.
@MainActor
final class PushSession: MfaFactorSession {
    private var state = PushApprovalState()
    private let offer: MfaFactorOffer
    private let transport: PushTransport
    private let policy: PushPollingPolicy
    private let clock: MfaClock
    private weak var host: MfaFactorHost?
    private var poll: Task<Void, Never>?
    private var inFlight: Task<Void, Never>?
    /// Set when the flow is over: nothing more is reported or sent.
    private var isStopped = false

    init(offer: MfaFactorOffer, transport: PushTransport, policy: PushPollingPolicy, clock: MfaClock,
         host: MfaFactorHost) {
        self.offer = offer
        self.transport = transport
        self.policy = policy
        self.clock = clock
        self.host = host
    }

    var model: (any MfaFactorModel)? {
        // The first push is still being sent: nothing to show yet. A resend keeps the waiting screen up, with
        // "Resend" gone, so the user isn't bounced to the list or a spinner and the screen keeps its place.
        let isResending = state.phase == .sending && state.epoch > 1
        guard state.phase == .waiting || isResending else { return nil }
        return PushChallengeModel(
            deviceName: offer.label ?? "", canResend: state.canResend, canSwitch: host?.canSwitch ?? false,
            resend: MfaAction<Void> { [weak self] in self?.send(.resend) },
            switchFactor: MfaAction<Void> { [weak self] in self?.host?.switchFactor() },
            cancel: MfaAction<Void> { [weak self] in self?.host?.cancel() })
    }

    func start() { send(.start) }
    func deactivate() { send(.deactivate) }
    func appBecameActive() { send(.appBecameActive) }
    func appBecameInactive() { send(.appBecameInactive) }

    func cancelAndWait() async {
        isStopped = true
        poll?.cancel()
        poll = nil
        await inFlight?.value
    }

    private func send(_ event: PushApprovalEvent) {
        guard !isStopped else { return }
        let (next, effects) = PushApprovalMachine.reduce(state, event, policy: policy)
        state = next
        effects.forEach(run)
        host?.modelDidChange()
    }

    private func run(_ effect: PushApprovalEffect) {
        switch effect {
        case let .send(epoch):
            request(epoch) { session in
                .sent(try await session.transport.sendPush(to: session.offer), epoch: epoch)
            }
        case let .check(epoch):
            request(epoch) { session in .checked(try await session.transport.checkApproval(), epoch: epoch) }
        case let .schedulePoll(milliseconds, epoch):
            poll?.cancel()
            poll = Task { [weak self, clock] in
                do { try await clock.sleep(milliseconds: milliseconds) } catch { return }       // cancelled: no tick
                self?.send(.pollDue(epoch: epoch))
            }
        case .cancelPoll:
            poll?.cancel()
            poll = nil
        case let .report(report):
            switch report {
            case .completed: host?.completed()
            case let .anotherFactor(offers): host?.needsAnotherFactor(offers)
            case let .failed(error): host?.failed(error)
            }
        }
    }

    /// One request at a time. Cancelling a Task doesn't cancel its HTTP call, so wait for the last one.
    private func request(_ epoch: Int, _ call: @escaping (PushSession) async throws -> PushApprovalEvent) {
        let previous = inFlight
        inFlight = Task { [weak self] in
            await previous?.value
            // The user may have left (resent, switched, cancelled) while this waited: then it must not be sent.
            guard let self, !self.isStopped, self.state.isActive, self.state.epoch == epoch else { return }
            do {
                self.send(try await call(self))
            } catch {
                self.send(.failed(.from(error), epoch: epoch))
            }
        }
    }
}
