@testable import Auth0UniversalComponents
import Testing

@Suite
@MainActor
struct MfaFlowReducerTests {

    private let alpha = ScriptedFactor(.alpha, rank: 10)
    private let beta = ScriptedFactor(.beta, rank: 20)
    private let offerA0 = scriptedOffer("alpha:0", factor: .alpha, label: "A0")
    private let offerA1 = scriptedOffer("alpha:1", factor: .alpha, label: "A1")
    private let offerB0 = scriptedOffer("beta:0", factor: .beta, label: "B0")
    private let unknown = scriptedOffer("zeta:0", factor: "zeta")

    private var registry: MfaFactorRegistry { MfaFactorRegistry([alpha, beta]) }

    private func run(_ events: [MfaFlowEvent],
                     from state: MfaFlowState = MfaFlowState()) -> (MfaFlowState, [MfaFlowEffect]) {
        var current = state
        var all: [MfaFlowEffect] = []
        for event in events {
            let (next, effects) = MfaFlowReducer.reduce(current, event, registry: registry)
            current = next
            all += effects
        }
        return (current, all)
    }

    // MARK: Menus

    @Test func oneOffer_skipsTheList_andStartsItsSession() {
        let (state, effects) = run([.menu([offerA0], token: 0)])
        #expect(state.phase == .inFactor)
        #expect(state.current == offerA0)
        #expect(effects == [.startSession(offerA0, token: 1)])
    }

    @Test func twoOffers_showTheList_inRankOrder_serverOrderBreaksTies() {
        let (state, effects) = run([.menu([offerB0, offerA1, offerA0], token: 0)])
        #expect(state.phase == .choosing)
        #expect(state.offers.map(\.id) == ["alpha:1", "alpha:0", "beta:0"])
        #expect(effects.startCount == 0)
    }

    @Test func unsupportedFactors_areDropped_andNoneLeftEndsTheFlow() {
        #expect(run([.menu([unknown, offerA0], token: 0)]).0.phase == .inFactor)
        let (state, effects) = run([.menu([unknown], token: 0)])
        #expect(state.failure == .noEligibleFactors)
        #expect(effects.contains(.finish(.noEligibleFactors)))
    }

    @Test func anEmptyMenu_endsWithNoEligibleFactors() {
        #expect(run([.menu([], token: 0)]).0.failure == .noEligibleFactors)
    }

    @Test func aFourthRound_failsWithMaxChallengesExceeded() {
        var events: [MfaFlowEvent] = [.menu([offerA0, offerB0], token: 0)]
        var state = run(events).0
        for _ in 0..<3 {
            state = run([.select(id: "alpha:0")], from: state).0
            state = run([.menu([offerA0, offerB0], token: state.token)], from: state).0
        }
        events = []
        #expect(state.failure == .maxChallengesExceeded)
        #expect(state.round == 4)
    }

    @Test func aMenuFromTheRunningSession_startsTheNextRound_andRetiresIt() {
        let (first, _) = run([.menu([offerA0, offerB0], token: 0), .select(id: "alpha:0")])
        let (state, effects) = run([.menu([offerA0, offerB0], token: first.token)], from: first)
        #expect(state.phase == .choosing)
        #expect(state.round == 2)
        #expect(effects.contains(.deactivateAll))
    }

    /// The user approved on one device, then switched before the answer arrived: the server has moved to the next
    /// round, so the flow must too, as it does for a plain approval.
    @Test func aMenuFromASessionTheUserLeftThisRound_stillStartsTheNextRound() {
        let (state, _) = run([.menu([offerA0, offerB0], token: 0), .select(id: "alpha:0")])
        let old = state.token
        let (switched, _) = run([.switchFactor, .select(id: "beta:0")], from: state)
        let (after, effects) = run([.menu([offerA0, offerB0], token: old)], from: switched)
        #expect(after.round == 2)
        #expect(after.phase == .choosing)
        #expect(effects.first == .deactivateAll, "every session of the finished round stops")
    }

    @Test func aMenuFromAnEarlierRound_isIgnored() {
        let (first, _) = run([.menu([offerA0, offerB0], token: 0), .select(id: "alpha:0")])
        let roundOne = first.token
        let (second, _) = run([.menu([offerA0, offerB0], token: roundOne), .select(id: "beta:0")], from: first)
        let (after, effects) = run([.menu([offerA0, offerB0], token: roundOne)], from: second)
        #expect(after == second)
        #expect(effects.isEmpty)
    }

    @Test func theCap_isConfigurable() {
        var strict = MfaFlowState()
        strict.maxRounds = 1
        let (once, _) = run([.menu([offerA0, offerB0], token: 0), .select(id: "alpha:0")], from: strict)
        #expect(run([.menu([offerA0, offerB0], token: once.token)], from: once).0.failure == .maxChallengesExceeded)

        var generous = MfaFlowState()
        generous.maxRounds = 5
        var state = run([.menu([offerA0, offerB0], token: 0)], from: generous).0
        for _ in 0..<4 {
            state = run([.select(id: "alpha:0")], from: state).0
            state = run([.menu([offerA0, offerB0], token: state.token)], from: state).0
        }
        #expect(state.round == 5)
        #expect(state.failure == nil, "five rounds fit under a cap of five")
        #expect(run([.select(id: "alpha:0")], from: state).0.phase == .inFactor)
    }

    @Test func theDefaultCap_isTheSpecsThree() {
        #expect(MfaFlowState().maxRounds == 3)
        #expect(MfaConfiguration.defaultMaximumRounds == MfaFlowReducer.defaultMaxRounds)
    }

    @Test func aFactorUsedInAnEarlierRound_mayBeOfferedAgain() {
        let (first, _) = run([.menu([offerA0, offerB0], token: 0), .select(id: "alpha:0")])
        let (second, effects) = run([.menu([offerA0, offerB0], token: first.token), .select(id: "alpha:0")],
                                    from: first)
        #expect(second.round == 2)
        #expect(effects.contains(.startSession(offerA0, token: second.token)))
        #expect(second.token == first.token + 1, "a new session, not the old one")
    }

    // MARK: Selecting and switching

    @Test func select_startsASession_withAFreshToken() {
        let (listed, _) = run([.menu([offerA0, offerB0], token: 0)])
        let (state, effects) = run([.select(id: "beta:0")], from: listed)
        #expect(state.token == listed.token + 1)
        #expect(effects == [.startSession(offerB0, token: state.token)])
    }

    @Test func select_ofAnUnknownRow_doesNothing() {
        let (listed, _) = run([.menu([offerA0, offerB0], token: 0)])
        #expect(run([.select(id: "nope")], from: listed).1.isEmpty)
    }

    @Test func switching_returnsToTheList_andDeactivatesTheSession() {
        let (state, effects) = run([.menu([offerA0, offerB0], token: 0), .select(id: "alpha:0"), .switchFactor])
        #expect(state.phase == .choosing)
        #expect(state.current == nil)
        #expect(effects.last == .deactivateSession(token: 1))
    }

    @Test func switching_withNowhereToGo_doesNothing() {
        let (state, effects) = run([.menu([offerA0], token: 0), .switchFactor])
        #expect(state.phase == .inFactor)
        #expect(effects.count == 1)             // only the start
    }

    // MARK: Completing

    @Test func aVerifiedSession_isStoredThenAnnounced() {
        let (state, effects) = run([.menu([offerA0], token: 0), .completed(token: 1)])
        #expect(state.phase == .completing)
        #expect(effects.contains(.commit))
        let (done, announced) = run([.committed], from: state)
        #expect(done.phase == .finished)
        #expect(announced == [.finish(nil)])
    }

    @Test func aVerifiedAnswerOnItsWay_stillSignsIn_afterSwitching() {
        let (state, effects) = run([.menu([offerA0, offerB0], token: 0), .select(id: "alpha:0"), .switchFactor,
                                    .completed(token: 1)])
        #expect(state.phase == .completing)
        #expect(effects.contains(.commit))
    }

    @Test func cancel_isTerminal_andAnnouncedOnce() {
        let (state, effects) = run([.menu([offerA0, offerB0], token: 0), .cancel, .completed(token: 0),
                                    .select(id: "alpha:0"), .cancel])
        #expect(state.failure == .cancelled)
        #expect(effects.finishCount == 1)
    }

    @Test func aVerifiedAnswerAfterCancel_asksForNoStore() {
        let (_, effects) = run([.menu([offerA0, offerB0], token: 0), .select(id: "alpha:0"), .cancel,
                                .completed(token: 1)])
        #expect(!effects.contains(.commit))
    }

    @Test func cancelCannotInterruptTheStore() {
        let (state, effects) = run([.menu([offerA0], token: 0), .completed(token: 1), .cancel])
        #expect(state.phase == .completing)
        #expect(effects.finishCount == 0)
    }

    @Test func aStoreThatFails_endsWithThatError() {
        let (state, _) = run([.menu([offerA0], token: 0), .completed(token: 1), .commitFailed(.credentialsNotSaved)])
        #expect(state.failure == .credentialsNotSaved)
    }

    // MARK: Failing

    @Test func aFailureFromTheRunningSession_endsTheFlow() {
        let (state, effects) = run([.menu([offerA0], token: 0), .failed(.rejected, token: 1)])
        #expect(state.failure == .rejected)
        #expect(effects.contains(.finish(.rejected)))
    }

    @Test func aFailureFromASessionTheUserLeft_isIgnored() {
        let (state, effects) = run([.menu([offerA0, offerB0], token: 0), .select(id: "alpha:0"), .switchFactor,
                                    .failed(.rejected, token: 1)])
        #expect(state.phase == .choosing)
        #expect(effects.finishCount == 0)
    }
}
