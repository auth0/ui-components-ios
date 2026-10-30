@testable import Auth0UniversalComponents
import SwiftUI
import Testing

@Suite
@MainActor
struct MfaConfigurationTests {

    @Test func anOverride_changesOnlyItsLeaf() {
        let custom = MfaMessages.default.with {
            $0.authenticatorList.headers.challengeAdditional.title = "Almost there"
            $0.pushChallenge.description = { "Tap Approve on \($0)." }
        }
        let standard = MfaMessages.default
        #expect(custom.authenticatorList.headers.challengeAdditional.title == "Almost there")
        #expect(custom.authenticatorList.headers.challengeAdditional.description
                == standard.authenticatorList.headers.challengeAdditional.description)
        #expect(custom.authenticatorList.headers.challenge.title == standard.authenticatorList.headers.challenge.title)
        #expect(custom.pushChallenge.description("iPhone") == "Tap Approve on iPhone.")
        #expect(standard.pushChallenge.description("iPhone").contains("iPhone"))
    }

    @Test func aFactorsCopy_livesInItsOwnBranch_andCoreCopyIsUntouchedByIt() {
        let changed = MfaMessages.default.with { $0.pushChallenge.title = "Check your phone" }
        #expect(changed.pushChallenge.title == "Check your phone")
        #expect(changed.errors.rejected.title == MfaMessages.default.errors.rejected.title)
        #expect(MfaMessages.default.pushChallenge.title == "Check your device")
    }

    @Test func dynamicStrings_areFunctions() {
        #expect(MfaMessages.default.pushChallenge.resend.cooldown(42) == "Resend in 42 sec…")
    }

    /// The copy the shipped Guardian push screens used, so users see no change.
    @Test func defaults_keepTheShippedWording() {
        let messages = MfaMessages.default
        #expect(messages.pushChallenge.title == "Check your device")
        #expect(messages.pushChallenge.waiting == "Waiting for approval")
        #expect(messages.pushChallenge.resend.button == "Resend Code")
        #expect(messages.errors.rejected.title == "Sign-in request denied.")
        #expect(messages.errors.tokenExpired.title == "Request expired.")
        #expect(messages.errors.tokenInvalid.title == "Sign-in session ended.")
        #expect(messages.errors.network.title == "No connection.")
        #expect(messages.errors.noEligibleFactors.title == "Verification method not available.")
        #expect(messages.errors.credentialsNotSaved.description
                == "We couldn't save your sign-in on this device. Please try again.")
    }

    @Test func everyErrorHasItsOwnWording() {
        let all: [MfaError] = [.cancelled, .tokenExpired, .tokenInvalid, .maxChallengesExceeded, .rejected,
                               .tooManyAttempts, .noEligibleFactors, .presentationUnavailable, .network,
                               .credentialsNotSaved, .unexpected(nil)]
        let titles = all.map { MfaMessages.default.errors.message(for: $0).title }
        #expect(titles.allSatisfy { !$0.isEmpty })
        // Only the generic cases may share wording.
        #expect(Set(titles).count >= all.count - 3)
    }

    @Test func anUnexpectedErrorWithAMessage_showsIt() {
        let message = MfaMessages.default.errors.message(for: .unexpected("Sign-in is temporarily blocked."))
        #expect(message.description == "Sign-in is temporarily blocked.")
        #expect(message.title == MfaMessages.default.errors.unexpected.title)
    }

    @Test func aFactorsScreen_isReplacedByFactorId_theOthersStayStandard() {
        let screens = MfaScreens().replacing(.alpha) { (model: ScriptedModel) in Text(model.name) }
        #expect(screens.factorViews[.alpha] != nil)
        #expect(screens.factorViews[.beta] == nil)
        #expect(screens.authenticatorList.isStandard)
        #expect(screens.error.isStandard)
    }

    @Test func aReplacement_ignoresModelsThatAreNotItsFactors() {
        let screens = MfaScreens().replacing(.alpha) { (model: ScriptedModel) in Text(model.name) }
        let other = PushChallengeModel(deviceName: "iPhone")
        #expect(screens.factorViews[.alpha]?(other) == nil)
        #expect(screens.factorViews[.alpha]?(ScriptedModel(name: "x", switchFactor: .none, cancel: .none)) != nil)
    }

    @Test func theCallShapeOfTheCoreSlots_worksForAFactorToo() {
        let screens = MfaScreens(pushChallenge: .custom { (model: PushChallengeModel) in Text(model.deviceName) })
        #expect(screens.factorViews[.push] != nil)
        #expect(screens.authenticatorList.isStandard)
    }

    @Test func maximumRounds_defaultsToThree_andCanBeChanged() {
        #expect(MfaConfiguration().maximumRounds == 3)
        #expect(MfaConfiguration(maximumRounds: 5).maximumRounds == 5)
    }

    @Test func presentation_defaultsToStandard() {
        guard case .standard = MfaConfiguration().presentation else { Issue.record("expected standard"); return }
    }

    @Test func steps_haveAStableIdentity_thatIgnoresTheirPayload() {
        let first = MfaStep.authenticatorList(AuthenticatorListModel(header: .challenge, rows: []))
        let pending = MfaStep.authenticatorList(AuthenticatorListModel(header: .challenge, rows: [], pendingRowID: "x"))
        let additional = MfaStep.authenticatorList(AuthenticatorListModel(header: .challengeAdditional, rows: []))
        #expect(first.identity == pending.identity, "a row's progress updates in place")
        #expect(first.identity != additional.identity, "a second round is a new screen")
        let model = ScriptedModel(name: "x", switchFactor: .none, cancel: .none)
        #expect(MfaStep.factor(MfaFactorStep(factor: .alpha, model: model)).identity == "factor.alpha")
    }
}

private extension MfaScreenSlot {
    var isStandard: Bool {
        if case .standard = source { return true }
        return false
    }
}
