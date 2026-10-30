@testable import Auth0UniversalComponents
import Testing

/// Visits every state the flow reducer can reach, applies every kind of event (current and stale) to each, and checks
/// the rules a flow must keep. A failure names the state and the event.
@Suite
@MainActor
struct MfaFlowSearchTests {

    private let alpha = ScriptedFactor(.alpha, rank: 10)
    private let beta = ScriptedFactor(.beta, rank: 20)
    private let offerA0 = scriptedOffer("alpha:0", factor: .alpha)
    private let offerB0 = scriptedOffer("beta:0", factor: .beta)
    private let unknown = scriptedOffer("zeta:0", factor: "zeta")

    private struct StateKey: Hashable {
        let phase: String
        let round: Int
        let offers: [String]
        let current: String?
        let token: Int
        let sessionsThisRound: Int
        let failure: String?

        init(_ state: MfaFlowState) {
            phase = "\(state.phase)"
            round = state.round
            offers = state.offers.map(\.id)
            current = state.current?.id
            // The reducer only compares a token with the current one and with the start of the round, never its
            // value, so only those relations matter. Counting tokens would make the search endless.
            token = min(state.token, 1)
            sessionsThisRound = min(state.token - state.roundStartToken, 2)
            failure = state.failure.map { "\($0)" }
        }
    }

    private func invariantViolations(_ state: MfaFlowState) -> [String] {
        var found: [String] = []
        if state.phase == .choosing, !(state.current == nil && state.offers.count >= 2) {
            found.append("I1 choosing needs no current factor and 2+ offers")
        }
        if (state.phase == .failed) != (state.failure != nil) { found.append("I2 failed <=> failure is set") }
        if state.phase == .inFactor, state.current == nil { found.append("I3 a running factor needs an offer") }
        if state.phase == .idle, !(state.offers.isEmpty && state.round == 0 && state.token == 0) {
            found.append("I4 idle means nothing has happened yet")
        }
        if state.roundStartToken > state.token { found.append("I6 a round can't start after its sessions") }
        if state.round > state.maxRounds + 1 { found.append("I5 round beyond the cap") }
        if state.round == state.maxRounds + 1, state.failure != .maxChallengesExceeded {
            found.append("I5 a 4th round must fail")
        }
        return found
    }

    private func alphabet(_ state: MfaFlowState) -> [(label: String, event: MfaFlowEvent)] {
        let menus: [(String, [MfaFactorOffer])] = [
            ("one", [offerA0]), ("two", [offerA0, offerB0]), ("unsupported", [unknown]), ("none", [])
        ]
        var out: [(String, MfaFlowEvent)] = [
            ("cancel", .cancel), ("switch", .switchFactor), ("committed", .committed),
            ("commitFailed", .commitFailed(.credentialsNotSaved)),
            ("select", .select(id: "alpha:0")), ("select", .select(id: "beta:0")), ("select", .select(id: "nope"))
        ]
        for token in Set([0, state.token, state.token - 1, state.token + 1, state.roundStartToken]) {
            let stale = token == state.token ? "" : "stale "
            out.append((stale + "completed", .completed(token: token)))
            out.append((stale + "failed", .failed(.rejected, token: token)))
            for (name, offers) in menus { out.append((stale + "menu " + name, .menu(offers, token: token))) }
        }
        return out
    }

    private func transitionViolations(from old: MfaFlowState, to new: MfaFlowState, effects: [MfaFlowEffect],
                                      event: MfaFlowEvent, context: String) -> [String] {
        var found: [String] = []
        let unchanged = new == old && effects.isEmpty
        if old.isTerminal, !unchanged { found.append("T1 \(context): terminal state moved") }
        if !old.isTerminal, new.isTerminal, effects.finishCount != 1 {
            found.append("T2 \(context): terminal without exactly one finish")
        }
        if effects.contains(.commit), !(new.phase == .completing && old.phase != .completing) {
            found.append("T3 \(context): commit outside the completing transition")
        }
        if old.phase == .completing, event != .committed, !isCommitFailure(event), !unchanged {
            found.append("T4 \(context): moved while credentials were being stored")
        }
        if effects.startCount > 1 { found.append("T5 \(context): more than one session started at once") }
        if new.token < old.token { found.append("T6 \(context): token went backwards") }
        if case let .menu(_, token) = event, token > 0, token <= old.roundStartToken, !unchanged {
            found.append("T8 \(context): a session of an earlier round moved the flow")
        }
        for effect in effects {
            if case let .startSession(offer, token) = effect, token != new.token || new.current != offer {
                found.append("T7 \(context): started a session that isn't the current one")
            }
        }
        return found
    }

    private func isCommitFailure(_ event: MfaFlowEvent) -> Bool {
        if case .commitFailed = event { return true } else { return false }
    }

    @Test func everyReachableStateAndEvent_keepsTheRules() {
        let registry = MfaFactorRegistry([alpha, beta])
        var seen: Set<StateKey> = [StateKey(MfaFlowState())]
        var queue = [MfaFlowState()]
        var next = 0
        var violations: [String] = []

        while next < queue.count {
            let state = queue[next]
            next += 1
            violations += invariantViolations(state).map { "state \(StateKey(state)): \($0)" }
            for (label, event) in alphabet(state) {
                let (after, effects) = MfaFlowReducer.reduce(state, event, registry: registry)
                violations += transitionViolations(from: state, to: after, effects: effects, event: event,
                                                   context: "\(state.phase) + \(label)")
                if seen.insert(StateKey(after)).inserted { queue.append(after) }
            }
        }

        #expect(violations.isEmpty, "\(queue.count) states: \(violations.prefix(8))")
        #expect(queue.count > 30, "the search should reach the whole machine, reached \(queue.count)")
    }
}
