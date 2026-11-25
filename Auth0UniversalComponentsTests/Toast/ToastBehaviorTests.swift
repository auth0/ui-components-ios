@testable import Auth0UniversalComponents
import CoreGraphics
import Testing

@Suite
struct ToastBehaviorTests {

    // MARK: Time on screen

    @Test func oneLine_rests4Seconds() {
        #expect(ToastBehavior.hold(lines: 1, voiceOverRunning: false) == 4)
    }

    @Test func eachExtraLine_adds1Second() {
        #expect(ToastBehavior.hold(lines: 2, voiceOverRunning: false) == 5)
    }

    /// A toast is two lines at most, so a bigger count (or none) never changes the rest.
    @Test func lineCountIsClamped() {
        #expect(ToastBehavior.hold(lines: 5, voiceOverRunning: false) == 5)
        #expect(ToastBehavior.hold(lines: 0, voiceOverRunning: false) == 4)
        #expect(ToastBehavior.hold(lines: -3, voiceOverRunning: false) == 4)
    }

    @Test func voiceOver_holdsAtLeast6Seconds() {
        #expect(ToastBehavior.hold(lines: 1, voiceOverRunning: true) == 6)
        #expect(ToastBehavior.hold(lines: 2, voiceOverRunning: true) == 6)
    }

    // MARK: Swipe to dismiss

    @Test func swipeUp_pastTheDistance_dismisses() {
        #expect(ToastBehavior.shouldDismiss(swipe: -ToastBehavior.swipeDismissDistance))
        #expect(ToastBehavior.shouldDismiss(swipe: -200))
    }

    @Test func shortSwipe_orASwipeDown_keepsTheToast() {
        #expect(!ToastBehavior.shouldDismiss(swipe: 0))
        #expect(!ToastBehavior.shouldDismiss(swipe: -(ToastBehavior.swipeDismissDistance - 1)))
        #expect(!ToastBehavior.shouldDismiss(swipe: 80))
    }

    // MARK: Lines of a message

    @Test func lineCount_comesFromTheHeightOverOneLine() {
        #expect(ToastBehavior.lineCount(textHeight: 19, lineHeight: 19) == 1)
        #expect(ToastBehavior.lineCount(textHeight: 43, lineHeight: 19) == 2)
    }

    @Test func lineCount_withNothingMeasured_isOne() {
        #expect(ToastBehavior.lineCount(textHeight: 0, lineHeight: 0) == 1)
        #expect(ToastBehavior.lineCount(textHeight: 40, lineHeight: 0) == 1)
        #expect(ToastTextMetrics().lineCount == 1)
    }

    @Test func lineCount_neverPassesTwo() {
        #expect(ToastBehavior.lineCount(textHeight: 120, lineHeight: 19) == 2)
    }

    // MARK: Message identity

    /// The same words shown again are a new toast, so they replace the current one and restart its time.
    @Test func message_showingTheSameWordsAgain_isANewToast() {
        let first = Auth0ToastMessage("Email verified")
        let again = Auth0ToastMessage("Email verified")
        #expect(first.text == again.text)
        #expect(first != again)
        #expect(first.id != again.id)
    }

    // MARK: Theme

    @Test func sizes_defaultToTheDesign() {
        let sizes = DefaultAuth0SizeTokens()
        #expect(sizes.toastMinHeight == 56)
        #expect(sizes.toastMaxWidth == 370)
    }

    /// A custom size scale written before the toast keeps compiling, and gets the design's sizes.
    @Test func sizes_aThemeWrittenBeforeTheToast_getsTheDefaults() {
        struct OldSizes: Auth0SizeTokens {
            var buttonHeight: CGFloat { 48 }
            var inputHeight: CGFloat { 60 }
            var size2xlDimen: CGFloat { 48 }
            var size3xlDimen: CGFloat { 56 }
            var containerSizeLargeDimen: CGFloat { 52 }
            var iconSmall: CGFloat { 16 }
            var iconMedium: CGFloat { 24 }
            var iconLarge: CGFloat { 28 }
        }
        #expect(OldSizes().toastMinHeight == 56)
        #expect(OldSizes().toastMaxWidth == 370)
    }
}
