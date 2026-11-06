import Foundation

/// Runs one phone code, texted or spoken, from "send it" to "verified": the code check, one request at a time, and
/// resend with its countdown. It owns everything about the code; the Core only hears the result.
@MainActor
final class PhoneCodeSession: MfaFactorSession {
    private var state = PhoneCodeState()
    private let offer: MfaFactorOffer
    private let delivery: PhoneCodeDelivery
    private let transport: PhoneCodeTransport
    private let policy: PhoneCodePolicy
    private let clock: MfaClock
    private weak var host: MfaFactorHost?
    /// Counts the resend cooldown down, one second at a time, on the injected clock.
    private var tick: Task<Void, Never>?
    private var inFlight: Task<Void, Never>?
    /// Set when the flow is over: nothing more is reported or sent.
    private var isStopped = false

    init(offer: MfaFactorOffer, delivery: PhoneCodeDelivery, transport: PhoneCodeTransport, policy: PhoneCodePolicy,
         clock: MfaClock, host: MfaFactorHost) {
        self.offer = offer
        self.delivery = delivery
        self.transport = transport
        self.policy = policy
        self.clock = clock
        self.host = host
    }

    var model: (any MfaFactorModel)? {
        // The first code is still being sent: nothing to show yet. A resend keeps the code screen up, with "Resend"
        // gone, so the user isn't bounced to the list or a spinner.
        let isResending = state.phase == .sending && state.epoch > 1
        guard state.phase == .awaitingCode || state.phase == .verifying || isResending else { return nil }
        return PhoneCodeChallengeModel(
            delivery: delivery, destination: offer.label ?? "", codeLength: policy.codeLength,
            isVerifying: state.phase == .verifying, isCodeRejected: state.isCodeRejected,
            canResend: state.canResend, resendAvailableIn: state.resendAvailableIn,
            canSwitch: host?.canSwitch ?? false,
            submit: MfaAction<String> { [weak self] in self?.send(.submit(code: $0)) },
            resend: MfaAction<Void> { [weak self] in self?.send(.resend) },
            switchFactor: MfaAction<Void> { [weak self] in self?.host?.switchFactor() },
            cancel: MfaAction<Void> { [weak self] in self?.host?.cancel() })
    }

    func start() { send(.start) }

    func deactivate() {
        send(.deactivate)
        tick?.cancel()
        tick = nil
    }

    // Nothing is polled, so the app going away changes nothing: the countdown catches up from the wall clock.
    func appBecameActive() {}
    func appBecameInactive() {}

    func cancelAndWait() async {
        isStopped = true
        tick?.cancel()
        tick = nil
        await inFlight?.value
    }

    private func send(_ event: PhoneCodeEvent) {
        guard !isStopped else { return }
        let (next, effects) = PhoneCodeMachine.reduce(state, event, policy: policy)
        state = next
        effects.forEach(run)
        host?.modelDidChange()
    }

    private func run(_ effect: PhoneCodeEffect) {
        switch effect {
        case let .send(epoch):
            request(epoch) { session in .sent(try await session.transport.sendCode(to: session.offer), epoch: epoch) }
        case let .verify(code, epoch):
            request(epoch) { session in .verified(try await session.transport.verify(code: code), epoch: epoch) }
        case let .scheduleCooldownTick(milliseconds, epoch):
            scheduleCooldownTick(afterMs: milliseconds, epoch: epoch)
        case let .report(report):
            switch report {
            case .completed: host?.completed()
            case let .anotherFactor(offers): host?.needsAnotherFactor(offers)
            case let .failed(error): host?.failed(error)
            }
        }
    }

    private func scheduleCooldownTick(afterMs milliseconds: Int, epoch: Int) {
        tick?.cancel()
        let startedAt = Date()
        tick = Task { [weak self, clock] in
            do { try await clock.sleep(milliseconds: milliseconds) } catch { return }           // cancelled: no tick
            // The whole seconds that really passed, at least the one asked for: an app that was suspended meanwhile
            // catches up instead of making the user wait the countdown out again.
            let elapsed = Int(Date().timeIntervalSince(startedAt).rounded())
            self?.send(.cooldownTick(seconds: max(1, elapsed), epoch: epoch))
        }
    }

    /// One request at a time. Cancelling a Task doesn't cancel its HTTP call, so wait for the last one.
    private func request(_ epoch: Int, _ call: @escaping (PhoneCodeSession) async throws -> PhoneCodeEvent) {
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
