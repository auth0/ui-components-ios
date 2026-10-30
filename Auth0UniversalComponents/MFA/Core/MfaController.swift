import Combine
import Foundation
import SwiftUI

/// Runs one MFA flow. It feeds events to the flow reducer, starts and stops factor sessions, and publishes the current
/// step. It draws nothing and knows no particular factor: every factor-specific thing goes through `MfaFactor`.
@MainActor
final class MfaController: ObservableObject {
    @Published private(set) var step: MfaStep = .loading(LoadingModel(cancel: nil))

    let registry: MfaFactorRegistry
    private var state = MfaFlowState()
    private let initialOffers: [MfaFactorOffer]
    private let committer: MfaCommitter
    private let messages: MfaMessages
    private let environment: MfaFactorEnvironment
    private let exit: MfaExit
    private let onFinish: (MfaError?) -> Void
    private let onLeave: () -> Void
    private var stream: MfaStepStream?
    /// Every session that has been started and not yet shut down: the running one, and any the user switched away from.
    private var sessions: [Int: MfaFactorSession] = [:]
    private var hosts: [Int: SessionHost] = [:]

    /// - Parameters:
    ///   - initialOffers: What the server said when it asked for MFA.
    ///   - maximumRounds: How many menus the flow may show; a policy that needs several factors shows several.
    ///   - onFinish: Called once, when the flow ends. `nil` means the user is signed in and the credentials are stored.
    ///   - onLeave: The error screen's "Start over" or "Close".
    init(initialOffers: [MfaFactorOffer], registry: MfaFactorRegistry, committer: MfaCommitter,
         messages: MfaMessages = .default, clock: MfaClock = SystemMfaClock(), exit: MfaExit = .startOver,
         maximumRounds: Int = MfaFlowReducer.defaultMaxRounds,
         onFinish: @escaping (MfaError?) -> Void, onLeave: @escaping () -> Void = {}) {
        self.initialOffers = initialOffers
        self.registry = registry
        self.committer = committer
        self.messages = messages
        self.environment = MfaFactorEnvironment(clock: clock)
        self.exit = exit
        self.onFinish = onFinish
        self.onLeave = onLeave
        state.maxRounds = max(1, maximumRounds)
    }

    /// Whether the flow has ended, one way or the other.
    var isFinished: Bool { state.isTerminal }

    func start() {
        send(.menu(initialOffers, token: 0))
    }

    /// Headless: mirror every step, and how the flow ended, into the app's stream.
    func publish(to stream: MfaStepStream) {
        self.stream = stream
        // The stream outlives one flow (the login builds a new flow for every sign-in): clear the last one's ending.
        stream.result = nil
        stream.step = step
    }

    /// Headless: the flow no longer owns the app's stream. Its step goes back to `nil`, so the app stops drawing it,
    /// and nothing this flow does later reaches the stream, which the next flow may already be using.
    func detach() {
        stream?.step = nil
        stream = nil
    }

    func appBecameActive() { sessions.values.forEach { $0.appBecameActive() } }

    func appBecameInactive() { sessions.values.forEach { $0.appBecameInactive() } }

    /// Ends the flow as cancelled and waits for the requests in flight: the server allows one at a time, and the next
    /// sign-in must not start while a reply is still due.
    func cancelAndWait() async {
        send(.cancel)
        for session in Array(sessions.values) { await session.cancelAndWait() }
    }

    func send(_ event: MfaFlowEvent) {
        let (next, effects) = MfaFlowReducer.reduce(state, event, registry: registry)
        state = next
        republish()
        effects.forEach(run)
        // Effects can end the flow, which changes what is shown.
        republish()
    }

    /// The standard screen for a factor's model, if the factor has one.
    func standardView(for step: MfaFactorStep) -> AnyView? {
        registry.factor(for: step.factor)?.standardView(for: step.model, messages: messages)
    }

    // MARK: Effects

    private func run(_ effect: MfaFlowEffect) {
        switch effect {
        case let .startSession(offer, token):
            startSession(for: offer, token: token)
        case let .deactivateSession(token):
            sessions[token]?.deactivate()
        case .deactivateAll:
            sessions.values.forEach { $0.deactivate() }
        case .commit:
            commit()
        case let .finish(error):
            finish(error)
        }
    }

    private func startSession(for offer: MfaFactorOffer, token: Int) {
        guard let factor = registry.factor(for: offer.factor) else {
            send(.failed(.unexpected(nil), token: token))
            return
        }
        let host = SessionHost(controller: self, token: token)
        let session = factor.makeSession(for: offer, host: host, environment: environment)
        hosts[token] = host
        sessions[token] = session
        session.start()
    }

    /// Synchronous, in the same main-actor turn that accepted the sign-in: nothing can interleave.
    private func commit() {
        do {
            try committer.commit()
            send(.committed)
        } catch {
            send(.commitFailed(.from(error)))
        }
    }

    private func finish(_ error: MfaError?) {
        // Nothing may be stored once the flow has ended without signing in.
        if error != nil { committer.abandon() }
        stream?.result = error.map(MfaResult.ended) ?? .signedIn
        // With no screen to show (signed in, cancelled, nothing to verify with) the app has nothing left to draw.
        // An error screen stays until the user leaves it.
        if case .loading = project(state) { detach() }
        onFinish(error)
    }

    // MARK: Projection

    private func republish() {
        let next = project(state)
        if next != step { step = next }
        stream?.step = step
    }

    private func project(_ state: MfaFlowState) -> MfaStep {
        let cancel = MfaAction<Void> { [weak self] in self?.send(.cancel) }
        switch state.phase {
        case .idle:
            return .loading(LoadingModel(cancel: cancel))
        case .choosing:
            return list(for: state, pending: nil, cancel: cancel)
        case .inFactor:
            guard let offer = state.current else { return .loading(LoadingModel(cancel: cancel)) }
            if let model = sessions[state.token]?.model {
                return .factor(MfaFactorStep(factor: offer.factor, model: model, round: state.round))
            }
            // The factor is still preparing. With somewhere else to go the list stays, with progress on the row.
            return state.canSwitch ? list(for: state, pending: offer.id, cancel: cancel)
                                   : .loading(LoadingModel(cancel: cancel))
        case .completing, .finished:
            return .loading(LoadingModel(cancel: nil))                // the sign-in is accepted, or the flow is over
        case .failed:
            return failed(state)
        }
    }

    private func list(for state: MfaFlowState, pending: String?, cancel: MfaAction<Void>) -> MfaStep {
        let rows: [AuthenticatorListModel.Row] = state.offers.compactMap { offer -> AuthenticatorListModel.Row? in
            guard let factor = registry.factor(for: offer.factor) else { return nil }
            let row = factor.row(for: offer, messages: messages)
            return .init(id: offer.id, factor: offer.factor, title: row.title, subtitle: row.subtitle, icon: row.icon)
        }
        return .authenticatorList(AuthenticatorListModel(
            header: state.round > 1 ? .challengeAdditional : .challenge, round: state.round, rows: rows,
            pendingRowID: pending,
            select: MfaAction<String> { [weak self] in self?.send(.select(id: $0)) }, cancel: cancel))
    }

    private func failed(_ state: MfaFlowState) -> MfaStep {
        switch state.failure {
        case .cancelled?, .noEligibleFactors?, nil:
            return .loading(LoadingModel(cancel: nil))              // no screen: the host reacts to onFinish
        case let error?:
            let leave = MfaAction<Void> { [weak self] in
                self?.detach()
                self?.onLeave()
            }
            return .error(ErrorModel(error: error, exit: exit, leave: leave))
        }
    }

    /// What one session may tell the Core. Each carries the token of the session it belongs to.
    private final class SessionHost: MfaFactorHost {
        private weak var controller: MfaController?
        private let token: Int

        init(controller: MfaController, token: Int) {
            self.controller = controller
            self.token = token
        }

        var canSwitch: Bool { controller?.state.canSwitch ?? false }
        func modelDidChange() { controller?.republish() }
        func completed() { controller?.send(.completed(token: token)) }
        func needsAnotherFactor(_ offers: [MfaFactorOffer]) { controller?.send(.menu(offers, token: token)) }
        func failed(_ error: MfaError) { controller?.send(.failed(error, token: token)) }
        func switchFactor() { controller?.send(.switchFactor) }
        func cancel() { controller?.send(.cancel) }
    }
}
