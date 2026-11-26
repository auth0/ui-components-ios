@testable import Auth0UniversalComponents
import CoreGraphics
import Foundation
import Testing

/// The life of a toast: when it is announced, how long it rests, and what ends it, run on a clock the test moves.
@MainActor
@Suite
struct ToastPresenterTests {

    private let fadeIn = ToastBehavior.appearDuration

    // MARK: Announcement

    @Test func aToast_isAnnouncedOnce_afterTheFadeIn() async {
        let harness = ToastPresenterHarness()
        let toast = Auth0ToastMessage("Email verified")

        await harness.show(toast)
        #expect(harness.announced.isEmpty, "not before it is in")

        await harness.clock.advance(by: fadeIn)
        #expect(harness.announced == ["Email verified"])

        await harness.clock.advance(by: 1)
        #expect(harness.announced == ["Email verified"])
    }

    @Test func aToastReplacedBeforeItIsIn_isNeverAnnounced() async {
        let harness = ToastPresenterHarness()
        await harness.show(Auth0ToastMessage("First"))
        await harness.clock.advance(by: 0.1)

        await harness.show(Auth0ToastMessage("Second"))
        await harness.clock.advance(by: 5)

        #expect(harness.announced == ["Second"])
    }

    // MARK: Time on screen

    @Test func aToast_rests4Seconds_thenGoes() async {
        let harness = ToastPresenterHarness()
        let toast = Auth0ToastMessage("Email verified")
        await harness.show(toast)

        await harness.clock.advance(by: fadeIn + 3.9)
        #expect(harness.sut.current == toast)
        #expect(harness.cleared.isEmpty)

        await harness.clock.advance(by: 0.2)
        #expect(harness.sut.current == nil)
        #expect(harness.cleared == [toast.id])
    }

    @Test func aMessageThatWraps_rests5Seconds() async {
        let harness = ToastPresenterHarness()
        let toast = Auth0ToastMessage("A longer message that needs a second line")
        await harness.show(toast)
        harness.sut.measured(wraps: true, id: toast.id)

        await harness.clock.advance(by: fadeIn + 4.5)
        #expect(harness.sut.current == toast)
        await harness.clock.advance(by: 0.6)
        #expect(harness.cleared == [toast.id])
    }

    /// B was never measured: it rests the base time, not the 5 s that A needed.
    @Test func whatWasMeasuredForOneToast_doesNotSetTheNext() async {
        let harness = ToastPresenterHarness()
        let first = Auth0ToastMessage("A long message")
        await harness.show(first)
        harness.sut.measured(wraps: true, id: first.id)
        await harness.clock.advance(by: fadeIn)

        let second = Auth0ToastMessage("Short")
        await harness.show(second)
        await harness.clock.advance(by: fadeIn + 4.1)

        #expect(harness.cleared == [second.id])
    }

    /// The layout can report before the presenter has started the toast: the answer is still the toast's.
    @Test func aMeasurementThatArrivesBeforeTheToastStarts_isStillUsed() async {
        let harness = ToastPresenterHarness()
        let toast = Auth0ToastMessage("A longer message that needs a second line")

        harness.sut.measured(wraps: true, id: toast.id)
        await harness.show(toast)
        await harness.clock.advance(by: fadeIn + 4.5)
        #expect(harness.sut.current == toast, "5 s, not 4")

        await harness.clock.advance(by: 0.6)
        #expect(harness.cleared == [toast.id])
    }

    @Test func aMeasurementForAToastThatWasReplaced_isIgnored() async {
        let harness = ToastPresenterHarness()
        let first = Auth0ToastMessage("First")
        let second = Auth0ToastMessage("Second")
        await harness.show(first)
        await harness.show(second)

        harness.sut.measured(wraps: true, id: first.id)
        await harness.clock.advance(by: fadeIn + 4.1)

        #expect(harness.cleared == [second.id])
    }

    @Test func aCustomDuration_isHowLongItRests() async {
        let harness = ToastPresenterHarness()
        let toast = Auth0ToastMessage("Link copied", duration: 2)
        await harness.show(toast)

        await harness.clock.advance(by: fadeIn + 1.9)
        #expect(harness.sut.current == toast)
        await harness.clock.advance(by: 0.2)
        #expect(harness.cleared == [toast.id])
    }

    /// The sleeps a toast asks for are always finite and within the cap, whatever the app passed.
    @Test(arguments: [TimeInterval.infinity, -.infinity, .nan, 1e30, .greatestFiniteMagnitude, -5])
    func anOddDuration_asksForASafeSleep(duration: TimeInterval) async {
        let harness = ToastPresenterHarness()
        await harness.show(Auth0ToastMessage("Odd", duration: duration))
        await harness.clock.advance(by: fadeIn)

        #expect(harness.clock.requested.count == 2, "the fade-in, then the rest")
        let rest = harness.clock.requested.last ?? -1
        #expect(rest.isFinite)
        #expect((0...ToastBehavior.maxHold).contains(rest), "\(rest)")
    }

    @Test func aDurationThatIsNotANumber_restsTheDefault() async {
        let harness = ToastPresenterHarness()
        let toast = Auth0ToastMessage("Odd", duration: .nan)
        await harness.show(toast)
        await harness.clock.advance(by: fadeIn + 4.1)
        #expect(harness.cleared == [toast.id])
    }

    @Test func withVoiceOver_aToastRestsAtLeast6Seconds() async {
        let harness = ToastPresenterHarness()
        harness.sut.voiceOverChanged(true)
        let toast = Auth0ToastMessage("Email verified")
        await harness.show(toast)

        await harness.clock.advance(by: fadeIn + 5.9)
        #expect(harness.sut.current == toast)
        await harness.clock.advance(by: 0.2)
        #expect(harness.cleared == [toast.id])
    }

    /// VoiceOver was turned on after the toast appeared: the hold is decided when the rest starts, not before.
    @Test func voiceOverTurnedOnWhileTheToastFadesIn_isHonoured() async {
        let harness = ToastPresenterHarness()
        let toast = Auth0ToastMessage("Email verified")
        await harness.show(toast)
        await harness.clock.advance(by: 0.1)

        harness.sut.voiceOverChanged(true)
        await harness.clock.advance(by: fadeIn + 5.5)

        #expect(harness.cleared.isEmpty)
    }

    // MARK: Replace, cancel, dismiss

    @Test func aNewToast_replacesTheCurrentOne_andTheOldTimerNeverClearsIt() async {
        let harness = ToastPresenterHarness()
        let first = Auth0ToastMessage("First")
        let second = Auth0ToastMessage("Second")
        await harness.show(first)
        await harness.clock.advance(by: fadeIn + 3)

        await harness.show(second)
        #expect(harness.sut.current == second)
        await harness.clock.advance(by: 1.5)
        #expect(harness.cleared.isEmpty, "the first one's 4 s are over, and it must not clear the second")

        await harness.clock.advance(by: fadeIn + 4)
        #expect(harness.cleared == [second.id])
        #expect(harness.announced == ["First", "Second"])
    }

    @Test func theSameWordsAgain_isANewToast_withItsOwnTime() async {
        let harness = ToastPresenterHarness()
        await harness.show(Auth0ToastMessage("Email verified"))
        await harness.clock.advance(by: fadeIn + 3)
        await harness.show(Auth0ToastMessage("Email verified"))
        await harness.clock.advance(by: fadeIn)

        #expect(harness.announced == ["Email verified", "Email verified"])
        await harness.clock.advance(by: 3.5)
        #expect(harness.cleared.isEmpty, "a fresh 4 s, not what was left of the first")
    }

    @Test func theSameToastTwice_doesNotRestartIt() async {
        let harness = ToastPresenterHarness()
        let toast = Auth0ToastMessage("Email verified")
        await harness.show(toast)
        await harness.clock.advance(by: fadeIn + 2)

        await harness.show(toast)
        await harness.clock.advance(by: 2.1)

        #expect(harness.cleared == [toast.id])
        #expect(harness.announced.count == 1)
    }

    @Test func theAppClearingTheBinding_endsTheToast_withoutClearingItAgain() async {
        let harness = ToastPresenterHarness()
        await harness.show(Auth0ToastMessage("Email verified"))
        await harness.clock.advance(by: fadeIn + 1)

        await harness.show(nil)
        await harness.clock.advance(by: 10)

        #expect(harness.sut.current == nil)
        #expect(harness.cleared.isEmpty)
    }

    @Test func aClearedToast_neverAnnouncesLater() async {
        let harness = ToastPresenterHarness()
        await harness.show(Auth0ToastMessage("Email verified"))
        await harness.clock.advance(by: 0.1)
        await harness.show(nil)
        await harness.clock.advance(by: 10)
        #expect(harness.announced.isEmpty)
    }

    @Test func dismissingAToastThatWasReplaced_changesNothing() async {
        let harness = ToastPresenterHarness()
        let first = Auth0ToastMessage("First")
        let second = Auth0ToastMessage("Second")
        await harness.show(first)
        await harness.show(second)

        harness.sut.dismiss(id: first.id)

        #expect(harness.sut.current == second)
        #expect(harness.cleared.isEmpty)
    }
}
