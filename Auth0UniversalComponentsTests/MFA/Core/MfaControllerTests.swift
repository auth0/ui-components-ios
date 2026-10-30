@testable import Auth0UniversalComponents
import SwiftUI
import Testing

/// The Core driven with generic scripted factors. Nothing here knows what a factor does inside.
@Suite
@MainActor
struct MfaControllerTests { // swiftlint:disable:this type_body_length

    private let alpha = ScriptedFactor(.alpha, rank: 10)
    private let beta = ScriptedFactor(.beta, rank: 20)
    private let committer = FakeCommitter()
    private let finish = FinishLog()
    private let offerA0 = scriptedOffer("alpha:0", factor: .alpha, label: "Alpha zero")
    private let offerB0 = scriptedOffer("beta:0", factor: .beta, label: "Beta zero")

    private func controller(_ offers: [MfaFactorOffer], exit: MfaExit = .startOver,
                            onLeave: @escaping () -> Void = {}) -> MfaController {
        MfaController(initialOffers: offers, registry: MfaFactorRegistry([alpha, beta]), committer: committer,
                      exit: exit, onFinish: { [finish] in finish.record($0) }, onLeave: onLeave)
    }

    private func list(_ sut: MfaController) -> AuthenticatorListModel? {
        if case let .authenticatorList(model) = sut.step { return model }
        return nil
    }

    private func factorModel(_ sut: MfaController) -> ScriptedModel? {
        if case let .factor(step) = sut.step { return step.model as? ScriptedModel }
        return nil
    }

    // MARK: Showing steps

    @Test func oneOffer_startsItsSession_andShowsLoadingUntilItIsReady() {
        let sut = controller([offerA0])
        sut.start()
        #expect(alpha.sessions.count == 1)
        guard case let .loading(model) = sut.step else { Issue.record("expected loading"); return }
        #expect(model.cancel != nil, "the user can still leave while the factor prepares")

        alpha.last.becomeReady()
        #expect(factorModel(sut)?.name == "alpha:0")
    }

    @Test func twoOffers_showTheList_wordedByEachFactor() {
        let sut = controller([offerB0, offerA0])
        sut.start()
        guard let model = list(sut) else { Issue.record("expected the list"); return }
        #expect(model.header == .challenge)
        #expect(model.rows.map(\.id) == ["alpha:0", "beta:0"], "rank order")
        #expect(model.rows.map(\.title) == ["Alpha zero", "Beta zero"])
        #expect(model.rows.map(\.subtitle) == ["alpha", "beta"])
        #expect(alpha.sessions.isEmpty && beta.sessions.isEmpty)
    }

    @Test func selecting_keepsTheList_withProgressOnTheRow_untilTheFactorIsReady() {
        let sut = controller([offerA0, offerB0])
        sut.start()
        list(sut)?.select("beta:0")
        #expect(beta.sessions.count == 1)
        #expect(list(sut)?.pendingRowID == "beta:0")

        beta.last.becomeReady()
        #expect(factorModel(sut)?.name == "beta:0")
    }

    @Test func aFactorsModelChange_isRepublished() {
        let sut = controller([offerA0])
        sut.start()
        alpha.last.becomeReady()
        let first = factorModel(sut)
        alpha.last.becomeReady()
        #expect(factorModel(sut) == first)
        guard case .factor = sut.step else { Issue.record("expected the factor's screen"); return }
    }

    // MARK: Switching

    @Test func switching_deactivatesTheSession_andReturnsToTheList() {
        let sut = controller([offerA0, offerB0])
        sut.start()
        list(sut)?.select("alpha:0")
        alpha.last.becomeReady()
        factorModel(sut)?.switchFactor()
        #expect(alpha.last.log.contains("deactivate"))
        #expect(list(sut) != nil)

        list(sut)?.select("beta:0")
        #expect(beta.sessions.count == 1)
    }

    @Test func aFactorWithNowhereToSwitchTo_isToldSo() {
        let sut = controller([offerA0])
        sut.start()
        alpha.last.becomeReady()
        factorModel(sut)?.switchFactor()
        guard case .factor = sut.step else { Issue.record("should stay on the factor"); return }
    }

    // MARK: Finishing

    @Test func aVerifiedFactor_isStoredOnce_thenTheFlowEndsSignedIn() {
        let stream = MfaStepStream()
        let sut = controller([offerA0])
        sut.publish(to: stream)
        sut.start()
        alpha.last.becomeReady()
        alpha.last.complete()
        #expect(committer.stored == 1)
        #expect(finish.results == [nil])
        #expect(stream.result == .signedIn)
        #expect(sut.isFinished)
    }

    @Test func aVerifiedAnswerOnItsWay_stillSignsIn_afterTheUserSwitched() {
        let sut = controller([offerA0, offerB0])
        sut.start()
        list(sut)?.select("alpha:0")
        alpha.last.becomeReady()
        factorModel(sut)?.switchFactor()
        alpha.last.complete()
        #expect(committer.stored == 1)
        #expect(finish.results == [nil])
    }

    @Test func cancel_discardsAVerifiedAnswerOnItsWay() {
        let sut = controller([offerA0, offerB0])
        sut.start()
        list(sut)?.select("alpha:0")
        alpha.last.becomeReady()
        factorModel(sut)?.cancel()
        alpha.last.complete()
        #expect(committer.stored == 0)
        #expect(committer.abandoned)
        #expect(finish.results == [.cancelled])
    }

    @Test func ifTheCredentialsCannotBeStored_theFlowEndsWithThatError() {
        committer.commitFails = true
        let sut = controller([offerA0])
        sut.start()
        alpha.last.becomeReady()
        alpha.last.complete()
        #expect(finish.results == [.credentialsNotSaved])
        #expect(committer.stored == 0)
    }

    // MARK: Rounds

    @Test func aFactorThatAsksForAnotherMenu_showsTheListWithTheAdditionalHeader() {
        let sut = controller([offerA0])
        sut.start()
        alpha.last.becomeReady()
        alpha.last.askForMenu([offerA0, offerB0])
        #expect(list(sut)?.header == .challengeAdditional)
        #expect(alpha.sessions.first?.log.contains("deactivate") == true)
    }

    @Test func eachRound_isNumbered_forScreensAndHeadlessApps() {
        let sut = controller([offerA0, offerB0])
        sut.start()
        #expect(list(sut)?.round == 1)
        list(sut)?.select("alpha:0")
        alpha.last.becomeReady()
        if case let .factor(step) = sut.step { #expect(step.round == 1) } else { Issue.record("expected a factor") }

        alpha.last.askForMenu([offerA0, offerB0])
        #expect(list(sut)?.round == 2)
        list(sut)?.select("beta:0")
        beta.last.becomeReady()
        if case let .factor(step) = sut.step { #expect(step.round == 2) } else { Issue.record("expected a factor") }
    }

    @Test func eachRound_startsAFreshSession_evenForTheSameFactor() {
        let sut = controller([offerA0, offerB0])
        sut.start()
        list(sut)?.select("alpha:0")
        alpha.last.becomeReady()
        alpha.last.askForMenu([offerA0, offerB0])
        list(sut)?.select("alpha:0")
        #expect(alpha.sessions.count == 2)
        #expect(alpha.sessions[0] !== alpha.sessions[1])
        #expect(alpha.sessions[1].model == nil, "the new session starts from nothing, not from the old one's screen")
    }

    @Test func aMultiStepSignIn_storesOnce_afterTheLastRound() {
        let sut = controller([offerA0, offerB0])
        sut.start()
        list(sut)?.select("alpha:0")
        alpha.last.becomeReady()
        alpha.last.askForMenu([offerB0, offerA0])
        #expect(committer.stored == 0, "nothing is stored until the whole policy is met")
        list(sut)?.select("beta:0")
        beta.last.becomeReady()
        beta.last.complete()
        #expect(committer.stored == 1)
        #expect(finish.results == [nil])
    }

    @Test func theNumberOfRounds_isConfigurable() {
        let sut = MfaController(initialOffers: [offerA0], registry: MfaFactorRegistry([alpha, beta]),
                                committer: committer, maximumRounds: 1, onFinish: { [finish] in finish.record($0) })
        sut.start()
        alpha.last.becomeReady()
        alpha.last.askForMenu([offerA0, offerB0])
        #expect(finish.results == [.maxChallengesExceeded])
    }

    @Test func aFourthMenu_endsTheFlow() {
        let sut = controller([offerA0])
        sut.start()
        for _ in 0..<3 {
            alpha.last.becomeReady()
            alpha.last.askForMenu([offerA0, offerB0])
            if list(sut) != nil { list(sut)?.select("alpha:0") }
        }
        #expect(finish.results == [.maxChallengesExceeded])
    }

    @Test func noSupportedFactor_showsNoScreen_andIsReported() {
        let sut = controller([scriptedOffer("zeta:0", factor: "zeta")])
        sut.start()
        guard case let .loading(model) = sut.step else { Issue.record("expected no screen"); return }
        #expect(model.cancel == nil)
        #expect(finish.results == [.noEligibleFactors])
    }

    // MARK: Failing and leaving

    @Test func aFailure_showsTheErrorScreen_withTheExitForTheEntryPoint() {
        var left = 0
        let sut = controller([offerA0], exit: .close, onLeave: { left += 1 })
        sut.start()
        alpha.last.fail(.tokenExpired)
        guard case let .error(model) = sut.step else { Issue.record("expected the error screen"); return }
        #expect(model.error == .tokenExpired)
        #expect(model.exit == .close)
        model.leave()
        #expect(left == 1)
        #expect(finish.results == [.tokenExpired])
    }

    @Test func aFailureFromASessionTheUserLeft_isIgnored() {
        let sut = controller([offerA0, offerB0])
        sut.start()
        list(sut)?.select("alpha:0")
        alpha.last.becomeReady()
        factorModel(sut)?.switchFactor()
        alpha.last.fail(.rejected)
        #expect(finish.results.isEmpty)
        #expect(list(sut) != nil)
    }

    @Test func cancelFromTheLoadingStep_ends_asCancelled() {
        let sut = controller([offerA0])
        sut.start()
        if case let .loading(model) = sut.step { model.cancel?() }
        #expect(finish.results == [.cancelled])
    }

    @Test func cancelAndWait_waitsForEverySessionsRequestInFlight() async {
        let sut = controller([offerA0, offerB0])
        sut.start()
        list(sut)?.select("alpha:0")
        alpha.last.holdsCancel = true
        var returned = false
        let waiter = Task { @MainActor in
            await sut.cancelAndWait()
            returned = true
        }
        await settle()
        #expect(!returned, "a request is still on the wire")
        alpha.last.releaseCancel()
        await waiter.value
        #expect(returned)
        #expect(finish.results == [.cancelled])
    }

    @Test func aNextMenuOnItsWay_startsTheNextRound_afterTheUserSwitched() {
        let sut = controller([offerA0, offerB0])
        sut.start()
        list(sut)?.select("alpha:0")
        alpha.last.becomeReady()
        let left = alpha.last
        factorModel(sut)?.switchFactor()
        list(sut)?.select("beta:0")
        left.askForMenu([offerA0, offerB0])                      // approved on alpha, and the policy wants more
        #expect(list(sut)?.round == 2)
        #expect(list(sut)?.header == .challengeAdditional)
        #expect(beta.last.log.contains("deactivate"), "the round it replaced stops")
    }

    // MARK: App lifecycle and headless

    @Test func appLifecycle_reachesTheSessions() {
        let sut = controller([offerA0])
        sut.start()
        sut.appBecameInactive()
        sut.appBecameActive()
        #expect(alpha.last.log.suffix(2) == ["inactive", "active"])
    }

    @Test func headless_theStreamReceivesEveryStep_andHowTheFlowEnded() {
        let stream = MfaStepStream()
        let sut = controller([offerA0, offerB0])
        sut.publish(to: stream)
        sut.start()
        guard case .authenticatorList? = stream.step else { Issue.record("stream missed the list"); return }
        list(sut)?.cancel()
        #expect(stream.result == .ended(.cancelled))
    }

    /// The app draws `stream.step` over the login. Once the flow has nothing to show, the step must go, or the app's
    /// last MFA screen would sit over email entry.
    @Test func headless_aFlowThatEndsWithNoScreen_clearsTheStep() {
        for end in ["signed in", "cancelled", "no factor"] {
            let stream = MfaStepStream()
            let sut = controller(end == "no factor" ? [] : [offerA0])
            sut.publish(to: stream)
            sut.start()
            if end == "signed in" {
                alpha.last.becomeReady()
                alpha.last.complete()
            } else if end == "cancelled" {
                sut.send(.cancel)
            }
            #expect(stream.step == nil, "\(end)")
            #expect(stream.result != nil, "\(end)")
        }
    }

    @Test func headless_anErrorScreenStays_untilTheUserLeavesIt() {
        let stream = MfaStepStream()
        var left = false
        let sut = controller([offerA0], onLeave: { left = true })
        sut.publish(to: stream)
        sut.start()
        alpha.last.fail(.rejected)
        guard case let .error(model)? = stream.step else { Issue.record("the error should be drawn"); return }
        model.leave()
        #expect(left)
        #expect(stream.step == nil)
    }

    /// The login builds a new flow for each sign-in, all publishing into the app's one stream.
    @Test func headless_theNextFlowStartsClean_andTheLastOneCantReachIt() {
        let stream = MfaStepStream()
        let first = controller([offerA0, offerB0])
        first.publish(to: stream)
        first.start()
        list(first)?.select("alpha:0")
        let late = alpha.last
        first.send(.cancel)
        first.detach()
        #expect(stream.result == .ended(.cancelled))

        let second = controller([offerA0, offerB0])
        second.publish(to: stream)
        second.start()
        #expect(stream.result == nil, "the last flow's ending is gone")
        late.becomeReady()                                      // the first flow's session reports late
        guard case .authenticatorList? = stream.step else { Issue.record("the second flow's list"); return }
    }

    @Test func steps_compareEqual_whateverTheirClosuresDo() {
        let first = AuthenticatorListModel(header: .challenge, rows: [], select: .init { _ in })
        let second = AuthenticatorListModel(header: .challenge, rows: [], select: .init { _ in _ = 1 })
        #expect(MfaStep.authenticatorList(first) == MfaStep.authenticatorList(second))
        let model = ScriptedModel(name: "x", switchFactor: .none, cancel: .none)
        #expect(MfaStep.factor(MfaFactorStep(factor: .alpha, model: model))
                == MfaStep.factor(MfaFactorStep(factor: .alpha, model: model)))
        #expect(MfaStep.factor(MfaFactorStep(factor: .alpha, model: model))
                != MfaStep.factor(MfaFactorStep(factor: .beta, model: model)))
    }
}
