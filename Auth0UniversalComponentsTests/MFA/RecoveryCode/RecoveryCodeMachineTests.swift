@testable import Auth0UniversalComponents
import Testing

/// Every decision of the recovery code factor, with no UI or network.
@Suite
struct RecoveryCodeMachineTests {

    private func run(_ events: [RecoveryCodeEvent], from state: RecoveryCodeState = RecoveryCodeState())
        -> (RecoveryCodeState, [RecoveryCodeEffect]) {
        var state = state
        var effects: [RecoveryCodeEffect] = []
        for event in events {
            (state, effects) = RecoveryCodeMachine.reduce(state, event)
        }
        return (state, effects)
    }

    private var saving: RecoveryCodeState {
        run([.submit("OLD"), .verified(.rotated(newCode: "NEW"))]).0
    }

    // MARK: Typing the code

    @Test func aCode_isChecked_withoutTheSpacesAroundIt() {
        let (state, effects) = run([.submit("  ABC123 \n")])
        #expect(state.phase == .verifying)
        #expect(effects == [.verify("ABC123")])
    }

    /// A pasted code can carry characters that show as nothing: the server sees them and calls the code wrong.
    @Test(arguments: [
        "ABC123\u{200E}",          // left-to-right mark
        "ABC\u{200B}123",          // zero-width space inside
        "\u{200F}ABC123\u{200D}",  // right-to-left mark, zero-width joiner
        "AB\u{2060}C123",          // word joiner
        "ABC\u{00AD}123",          // soft hyphen
        "\u{FEFF} ABC123\u{00A0}"  // byte-order mark, no-break space
    ])
    func invisibleCharacters_areNotSent(_ pasted: String) {
        #expect(run([.submit(pasted)]).1 == [.verify("ABC123")])
    }

    @Test func theCharactersOfTheCode_areSentAsTheyAre() {
        #expect(run([.submit("abC-12 3")]).1 == [.verify("abC-12 3")])
    }

    @Test(arguments: ["", "   ", "\n", "\u{200B}", "\u{200E} \u{FEFF}"])
    func anEmptyCode_isIgnored(_ typed: String) {
        let (state, effects) = run([.submit(typed)])
        #expect(state.phase == .entering)
        #expect(effects.isEmpty)
    }

    @Test func aSecondSubmitWhileChecking_isIgnored() {
        #expect(run([.submit("ABC"), .submit("DEF")]).1.isEmpty)
    }

    @Test func aWrongCode_staysForAnotherTry_andTheNextSubmitClearsIt() {
        let (rejected, effects) = run([.submit("BAD"), .verified(.rejected)])
        #expect(rejected.phase == .entering)
        #expect(rejected.isCodeRejected)
        #expect(effects.isEmpty)
        #expect(run([.submit("GOOD")], from: rejected).0.isCodeRejected == false)
    }

    // MARK: Saving the new code

    @Test func anAcceptedCode_showsTheNewOne_untilItIsConfirmed() {
        #expect(saving.phase == .saving)
        #expect(saving.newCode == "NEW")
    }

    @Test func confirming_asksTheServer_once() {
        let (state, effects) = run([.confirm], from: saving)
        #expect(state.phase == .confirming)
        #expect(effects == [.confirm])
        #expect(run([.confirm, .confirm], from: saving).1.isEmpty)
    }

    @Test func confirmingBeforeACodeIsShown_isIgnored() {
        #expect(run([.confirm]).1.isEmpty)
    }

    @Test func aConfirmedCode_signsIn_andKeepsNothing() {
        let (state, effects) = run([.confirm, .confirmed(.verified)], from: saving)
        #expect(state.phase == .finished)
        #expect(state.newCode == nil)
        #expect(effects == [.report(.completed)])
    }

    @Test func aConfirmedCode_canLeadToAnotherFactor() {
        let next = [MfaFactorOffer(id: "push:0", factor: .push, label: "iPhone", reference: 0)]
        let (_, effects) = run([.confirm, .confirmed(.anotherFactor(next))], from: saving)
        #expect(effects == [.report(.anotherFactor(next))])
    }

    // MARK: Failures

    /// Nothing was lost when the request never reached the server: the same step can be tried again.
    @Test func aDroppedConnectionWhileChecking_goesBackToTheField() {
        let (state, effects) = run([.submit("ABC"), .failed(.network)])
        #expect(state.phase == .entering)
        #expect(state.requestError == .network)
        #expect(effects.isEmpty)
        let (again, retry) = run([.submit("ABC")], from: state)
        #expect(again.requestError == nil)
        #expect(retry == [.verify("ABC")])
    }

    /// The code was already replaced: losing the new one here would lock the user out.
    @Test func aDroppedConnectionWhileConfirming_keepsTheNewCodeOnScreen() {
        let (state, effects) = run([.confirm, .failed(.network)], from: saving)
        #expect(state.phase == .saving)
        #expect(state.newCode == "NEW")
        #expect(state.requestError == .network)
        #expect(effects.isEmpty)
        #expect(run([.confirm], from: state).1 == [.confirm])
    }

    @Test(arguments: [MfaError.tokenInvalid, .tooManyAttempts, .tokenExpired, .unexpected(nil)])
    func anyOtherFailure_endsTheFactor_andKeepsNothing(_ error: MfaError) {
        let (state, effects) = run([.submit("ABC"), .failed(error)])
        #expect(state.phase == .finished)
        #expect(effects == [.report(.failed(error))])
        let (confirming, confirmEffects) = run([.confirm, .failed(error)], from: saving)
        #expect(confirming.newCode == nil)
        #expect(confirmEffects == [.report(.failed(error))])
    }

    @Test func aFailureWhenNothingIsOnItsWay_isDropped() {
        #expect(run([.failed(.tokenInvalid)]).1.isEmpty)
    }

    // MARK: Moving to another factor

    @Test func afterTheUserLeft_nothingNewIsSent() {
        let left = run([.deactivate]).0
        #expect(run([.submit("ABC")], from: left).1.isEmpty)
        let leftWhileSaving = run([.deactivate], from: saving).0
        #expect(run([.confirm], from: leftWhileSaving).1.isEmpty)
    }

    /// A confirmation already on its way still signs the user in: the server has moved on.
    @Test func aConfirmationOnItsWay_stillSignsIn() {
        let (_, effects) = run([.confirm, .deactivate, .confirmed(.verified)], from: saving)
        #expect(effects == [.report(.completed)])
    }
}
