@testable import Auth0UniversalComponents
import Testing

@Suite
struct RecoveryCodeMessagesTests {

    /// The words of the entry design.
    @Test func theDefaults_areTheEntryDesignsWords() {
        let sut = MfaMessages.default.recoveryCodeChallenge
        #expect(sut.title == "Enter the Recovery Code")
        #expect(sut.description == "Please enter your recovery code below.")
        #expect(sut.fieldLabel == "Recovery Code")
        #expect(sut.placeholder == "Your recovery code")
        #expect(sut.continueButton == "Continue")
    }

    /// The words of the save-the-new-code design.
    @Test func theSaveStep_usesTheDesignsWords() {
        let sut = MfaMessages.default.recoveryCodeChallenge
        #expect(sut.saveTitle == "Save your recovery code")
        #expect(sut.saveDescription == "This code works only once. Use it to sign in if you lose access to your device")
        #expect(sut.saveHelper == "Store this code somewhere safe, as it won't be shown again")
        #expect(sut.savedConfirmation == "I have saved this recovery code")
        #expect(sut.copied == "Copied")
        #expect(sut.copyCode == "Copy recovery code")
    }

    @Test func anOverride_changesOnlyItsLeaf() {
        let messages = MfaMessages.default.with { $0.recoveryCodeChallenge.title = "Use a recovery code" }
        #expect(messages.recoveryCodeChallenge.title == "Use a recovery code")
        #expect(messages.recoveryCodeChallenge.placeholder == "Your recovery code")
        #expect(messages.pushChallenge.title == MfaMessages.default.pushChallenge.title, "other factors are untouched")
    }
}
