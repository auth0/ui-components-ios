@testable import Auth0UniversalComponents
import Testing

/// A factor's step knows which session produced it, so equal models from two sessions are never taken for one step.
@Suite
@MainActor
struct MfaFactorStepTests {

    private let alpha = ScriptedFactor(.alpha, rank: 10)
    private let committer = FakeCommitter()
    private let finish = FinishLog()

    private func controller(_ offers: [MfaFactorOffer]) -> MfaController {
        MfaController(initialOffers: offers, registry: MfaFactorRegistry([alpha]), committer: committer,
                      onFinish: { [finish] in finish.record($0) })
    }

    private func list(_ sut: MfaController) -> AuthenticatorListModel? {
        if case let .authenticatorList(model) = sut.step { return model }
        return nil
    }

    @Test func aStep_remembersWhichSessionProducedIt() {
        let model = ScriptedModel(name: "iPhone", switchFactor: .none, cancel: .none)
        let first = MfaFactorStep(factor: .alpha, model: model, round: 1, sessionToken: 1)
        #expect(first == MfaFactorStep(factor: .alpha, model: model, round: 1, sessionToken: 1))
        #expect(first != MfaFactorStep(factor: .alpha, model: model, round: 1, sessionToken: 2),
                "equal models from different sessions are different steps")
        #expect(MfaFactorStep(factor: .alpha, model: model) == MfaFactorStep(factor: .alpha, model: model),
                "the public initializer is unchanged")
    }

    /// Two devices with the same name give equal models. The step must still change when the session does, or the
    /// screen would keep the old session's actions.
    @Test func switchingToASessionWithAnEqualModel_publishesADifferentStep() {
        let sut = controller([scriptedOffer("alpha:0", factor: .alpha, label: "iPhone"),
                              scriptedOffer("alpha:1", factor: .alpha, label: "iPhone")])
        sut.start()
        list(sut)?.select("alpha:0")
        alpha.last.becomeReady(named: "iPhone")
        guard case let .factor(first) = sut.step, let firstScreen = first.model as? ScriptedModel else {
            Issue.record("expected the first device's screen")
            return
        }
        firstScreen.switchFactor()
        list(sut)?.select("alpha:1")
        alpha.last.becomeReady(named: "iPhone")
        guard case let .factor(second) = sut.step else { Issue.record("expected the second device's screen"); return }

        #expect(first.model.isEqual(to: second.model), "the models alone can't tell the two devices apart")
        #expect(first != second)
        #expect(sut.step != .factor(first))
    }
}
