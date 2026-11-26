@testable import Auth0UniversalComponents
import CoreGraphics
import Foundation
import SwiftUI
import Testing

/// What a toast does when its screen comes and goes, and when the user drags it, on a clock the test moves.
@MainActor
@Suite
struct ToastPresenterLifecycleTests {

    private let fadeIn = ToastBehavior.appearDuration

    // MARK: The screen coming and going

    /// Otherwise it shows, and is announced, again for another 4 s when the screen comes back.
    @Test func whenTheScreenGoes_theToastGoesWithIt_andDoesNotReturn() async {
        let harness = ToastPresenterHarness()
        let toast = Auth0ToastMessage("Email verified")
        await harness.show(toast)
        await harness.clock.advance(by: fadeIn + 1)

        harness.sut.hostDisappeared()
        #expect(harness.sut.current == nil)
        #expect(harness.cleared == [toast.id])

        await harness.show(nil)       // the app's binding is now empty
        harness.sut.hostAppeared()
        await harness.clock.advance(by: 10)

        #expect(harness.sut.current == nil)
        #expect(harness.announced == ["Email verified"], "announced once, not again on return")
    }

    @Test func whenTheScreenGoesAfterTheToastEnded_nothingIsCleared() async {
        let harness = ToastPresenterHarness()
        let toast = Auth0ToastMessage("Email verified")
        await harness.show(toast)
        await harness.clock.advance(by: fadeIn + 4.1)
        #expect(harness.cleared == [toast.id])

        harness.sut.hostDisappeared()

        #expect(harness.cleared == [toast.id])
    }

    @Test func aToastSetBeforeTheScreenAppears_startsWhenItDoes() async {
        let harness = ToastPresenterHarness(hostVisible: false)
        let toast = Auth0ToastMessage("Account created")

        await harness.show(toast)
        await harness.clock.advance(by: 10)
        #expect(harness.announced.isEmpty)
        #expect(harness.sut.current == nil)

        harness.sut.hostAppeared()
        await harness.clock.settle()
        await harness.clock.advance(by: fadeIn)
        #expect(harness.announced == ["Account created"])
        #expect(harness.sut.current == toast)
    }

    // MARK: Swipe

    @Test func whileTheUserIsDragging_theToastStays() async {
        let harness = ToastPresenterHarness()
        let toast = Auth0ToastMessage("Email verified")
        await harness.show(toast)
        await harness.clock.advance(by: fadeIn + 1)

        harness.sut.dragChanged(active: true, id: toast.id)
        await harness.clock.advance(by: 100)

        #expect(harness.sut.current == toast)
        #expect(harness.cleared.isEmpty)
    }

    @Test func aDragThatEndsShortOfTheDistance_keepsTheToast_andRestartsItsTime() async {
        let harness = ToastPresenterHarness()
        let toast = Auth0ToastMessage("Email verified")
        await harness.show(toast)
        await harness.clock.advance(by: fadeIn + 1)

        harness.sut.dragChanged(active: true, id: toast.id)
        harness.sut.dragEnded(id: toast.id, translation: -10)
        harness.sut.dragChanged(active: false, id: toast.id)
        #expect(harness.sut.current == toast)

        await harness.clock.advance(by: 3.9)
        #expect(harness.sut.current == toast, "a full 4 s again")
        await harness.clock.advance(by: 0.2)
        #expect(harness.cleared == [toast.id])
    }

    @Test func atTheBottom_aDragDownDismisses_andOneUpDoesNot() async {
        let harness = ToastPresenterHarness()
        let toast = Auth0ToastMessage("Copied", style: .notice)
        await harness.show(toast)
        await harness.clock.advance(by: fadeIn)

        harness.sut.dragChanged(active: true, id: toast.id)
        harness.sut.dragEnded(id: toast.id, translation: -200, edge: .bottom)
        #expect(harness.sut.current == toast)

        harness.sut.dragEnded(id: toast.id, translation: ToastBehavior.swipeDismissDistance, edge: .bottom)
        #expect(harness.cleared == [toast.id])
    }

    @Test func aDragPastTheDistance_dismissesIt() async {
        let harness = ToastPresenterHarness()
        let toast = Auth0ToastMessage("Email verified")
        await harness.show(toast)
        await harness.clock.advance(by: fadeIn)

        harness.sut.dragChanged(active: true, id: toast.id)
        harness.sut.dragEnded(id: toast.id, translation: -ToastBehavior.swipeDismissDistance)

        #expect(harness.sut.current == nil)
        #expect(harness.cleared == [toast.id])
    }

    /// The system cancelled the drag: no end event, only the drag stopping. The toast must not stay forever.
    @Test func aDragTheSystemCancelled_letsTheToastGoAgain() async {
        let harness = ToastPresenterHarness()
        let toast = Auth0ToastMessage("Email verified")
        await harness.show(toast)
        await harness.clock.advance(by: fadeIn + 1)

        harness.sut.dragChanged(active: true, id: toast.id)
        harness.sut.dragChanged(active: false, id: toast.id)
        await harness.clock.advance(by: 4.1)

        #expect(harness.cleared == [toast.id])
    }

    /// A drag that started on the first toast must not dismiss, or hold, the one that replaced it.
    @Test func aDragOnAToastThatWasReplaced_doesNotTouchTheNewOne() async {
        let harness = ToastPresenterHarness()
        let first = Auth0ToastMessage("First")
        let second = Auth0ToastMessage("Second")
        await harness.show(first)
        await harness.clock.advance(by: fadeIn)
        harness.sut.dragChanged(active: true, id: first.id)

        await harness.show(second)
        harness.sut.dragEnded(id: first.id, translation: -200)
        harness.sut.dragChanged(active: false, id: first.id)

        #expect(harness.sut.current == second)
        await harness.clock.advance(by: fadeIn + 4.1)
        #expect(harness.cleared == [second.id], "the second toast ran its own time")
    }

    @Test func aDragThatStartsBeforeTheFadeInEnds_stillAnnouncesTheToast() async {
        let harness = ToastPresenterHarness()
        let toast = Auth0ToastMessage("Email verified")
        await harness.show(toast)
        await harness.clock.advance(by: 0.1)
        harness.sut.dragChanged(active: true, id: toast.id)

        await harness.clock.advance(by: 1)
        #expect(harness.announced == ["Email verified"])
        await harness.clock.advance(by: 100)
        #expect(harness.sut.current == toast, "held while the finger is down")

        harness.sut.dragChanged(active: false, id: toast.id)
        await harness.clock.advance(by: 4.1)
        #expect(harness.cleared == [toast.id])
    }
}
