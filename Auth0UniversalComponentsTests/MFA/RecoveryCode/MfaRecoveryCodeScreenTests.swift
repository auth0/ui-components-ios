@testable import Auth0UniversalComponents
import Testing

@Suite
@MainActor
struct MfaRecoveryCodeScreenTests {
    private let rejected = RecoveryCodeChallengeModel(isCodeRejected: true)

    private func isRejected(_ model: RecoveryCodeChallengeModel, code: String, submitted: String) -> Bool {
        MfaRecoveryCodeScreen.isRejected(model, code: code, submitted: submitted)
    }

    @Test func theRejectedCode_stillInTheField_isFlagged() {
        #expect(isRejected(rejected, code: "WRONG", submitted: "WRONG"))
    }

    /// The reported bug: the error, and the red text with it, stayed after the right code replaced the wrong one.
    @Test func anotherCodeInTheField_isNotFlagged() {
        #expect(!isRejected(rejected, code: "RIGHT", submitted: "WRONG"))
        #expect(!isRejected(rejected, code: "", submitted: "WRONG"))
        #expect(!isRejected(rejected, code: "WRONG ", submitted: "WRONG"))
    }

    @Test func aCodeThatWasntRejected_isNeverFlagged() {
        #expect(!isRejected(RecoveryCodeChallengeModel(), code: "WRONG", submitted: "WRONG"))
        #expect(!isRejected(RecoveryCodeChallengeModel(isVerifying: true), code: "WRONG", submitted: "WRONG"))
    }

    /// A screen shown already rejected, with nothing typed yet (a preview, or one rebuilt after the rejection).
    @Test func aFreshScreen_showsTheRejectionItWasGiven() {
        #expect(isRejected(rejected, code: "", submitted: ""))
    }
}
