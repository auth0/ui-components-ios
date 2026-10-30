import Foundation

/// Everything the Core knows about a flow: which menu round it is, which factor is running, how it ends.
/// Nothing in here depends on what a factor is.
struct MfaFlowState: Equatable {
    enum Phase: Equatable { case idle, choosing, inFactor, completing, finished, failed }

    var phase = Phase.idle
    /// How many menus the server has shown. The primary factor isn't a round. Each round is one step of a
    /// multi-step sign-in: a policy that needs two factors shows two menus.
    var round = 0
    /// A flow ends with `maxChallengesExceeded` when the server asks for more menus than this.
    var maxRounds = MfaFlowReducer.defaultMaxRounds
    var offers: [MfaFactorOffer] = []
    var current: MfaFactorOffer?
    /// Identifies the session that is running. Bumped on every start, so a report from an older one can be recognised.
    var token = 0
    /// The last token of the previous round. Sessions with a higher token were started in this round.
    var roundStartToken = 0
    var failure: MfaError?

    var canSwitch: Bool { offers.count > 1 }
    var isTerminal: Bool { phase == .finished || phase == .failed }
}

enum MfaFlowEvent: Equatable {
    /// A menu of factors: the first round (`token` 0) or an additional one reported by a session of this round.
    case menu([MfaFactorOffer], token: Int)
    case select(id: String)
    case switchFactor
    case cancel
    /// A session verified the user. Accepted from any session while the flow is live.
    case completed(token: Int)
    case failed(MfaError, token: Int)
    case committed
    case commitFailed(MfaError)
}

enum MfaFlowEffect: Equatable {
    case startSession(MfaFactorOffer, token: Int)
    case deactivateSession(token: Int)
    case deactivateAll
    /// Tell the committer to store the staged credentials, now.
    case commit
    /// `nil` means signed in.
    case finish(MfaError?)
}

/// Every decision the Core makes. Pure: no UI, no network, no clock, and no knowledge of any factor.
enum MfaFlowReducer {
    /// The cap the spec sets: a flow may show this many menus before a further one ends it.
    static let defaultMaxRounds = 3

    @MainActor
    static func reduce(_ old: MfaFlowState, _ event: MfaFlowEvent,
                       registry: MfaFactorRegistry) -> (MfaFlowState, [MfaFlowEffect]) {
        var state = old
        // Terminal: nothing more happens. That is also what keeps a late approval out of the Keychain after Cancel.
        if state.isTerminal { return (state, []) }
        let effects = state.apply(event, registry: registry)
        return (state, effects)
    }
}

// swiftlint:disable cyclomatic_complexity

extension MfaFlowState {
    @MainActor
    fileprivate mutating func apply(_ event: MfaFlowEvent, registry: MfaFactorRegistry) -> [MfaFlowEffect] {
        switch event {
        case let .menu(raw, token):
            return receiveMenu(raw, token: token, registry: registry)
        case let .select(id):
            guard phase == .choosing, let offer = offers.first(where: { $0.id == id }) else { return [] }
            return begin(offer)
        case .switchFactor:
            guard canSwitch, phase == .inFactor else { return [] }
            let old = token
            phase = .choosing
            current = nil
            return [.deactivateSession(token: old)]
        case .cancel:
            // Verified: the credentials are being stored.
            guard phase != .completing else { return [] }
            return failing(.cancelled)
        case .completed:
            // A verified answer on its way still signs the user in, whatever the user did since.
            guard phase != .completing else { return [] }
            phase = .completing
            return [.deactivateAll, .commit]
        case let .failed(error, token):
            guard phase == .inFactor, token == self.token else { return [] }
            return failing(error)
        case .committed:
            guard phase == .completing else { return [] }
            phase = .finished
            return [.finish(nil)]
        case let .commitFailed(error):
            guard phase == .completing else { return [] }
            return failing(error)
        }
    }

    @MainActor
    private mutating func receiveMenu(_ raw: [MfaFactorOffer], token: Int,
                                      registry: MfaFactorRegistry) -> [MfaFlowEffect] {
        // The first menu starts a flow. A later one means a session of this round was verified and the server moved
        // on, even if the user switched away from it since: like a verified answer, it still counts.
        let isFirst = phase == .idle && token == 0
        let isFromThisRound = (phase == .inFactor || phase == .choosing)
            && token > roundStartToken && token <= self.token
        guard isFirst || isFromThisRound else { return [] }
        let finished = isFirst ? [] : [MfaFlowEffect.deactivateAll]
        roundStartToken = self.token
        round += 1
        guard round <= maxRounds else { return finished + failing(.maxChallengesExceeded) }
        offers = registry.eligible(raw)
        current = nil
        switch offers.count {
        case 0:
            return finished + failing(.noEligibleFactors)
        case 1:
            return finished + begin(offers[0])                      // one factor: skip the list
        default:
            phase = .choosing
            return finished
        }
    }

    private mutating func begin(_ offer: MfaFactorOffer) -> [MfaFlowEffect] {
        token += 1
        current = offer
        phase = .inFactor
        return [.startSession(offer, token: token)]
    }

    private mutating func failing(_ error: MfaError) -> [MfaFlowEffect] {
        phase = .failed
        failure = error
        return [.deactivateAll, .finish(error)]
    }
}

// swiftlint:enable cyclomatic_complexity
