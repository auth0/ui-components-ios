@testable import Auth0UniversalComponents
import CoreGraphics
import SwiftUI
import Testing

@Suite
struct ToastBehaviorTests {

    // MARK: Time on screen

    @Test func oneLine_rests4Seconds() {
        #expect(ToastBehavior.hold(wraps: false, voiceOverRunning: false) == 4)
    }

    @Test func aSecondLine_adds1Second() {
        #expect(ToastBehavior.hold(wraps: true, voiceOverRunning: false) == 5)
    }

    @Test func voiceOver_holdsAtLeast6Seconds() {
        #expect(ToastBehavior.hold(wraps: false, voiceOverRunning: true) == 6)
        #expect(ToastBehavior.hold(wraps: true, voiceOverRunning: true) == 6)
    }

    @Test func aCustomDuration_isUsedAsItIs_whetherOrNotTheMessageWraps() {
        #expect(ToastBehavior.hold(wraps: false, voiceOverRunning: false, duration: 2) == 2)
        #expect(ToastBehavior.hold(wraps: true, voiceOverRunning: false, duration: 2) == 2)
        #expect(ToastBehavior.hold(wraps: false, voiceOverRunning: false, duration: 10) == 10)
    }

    @Test func aCustomDuration_stillHoldsForVoiceOver() {
        #expect(ToastBehavior.hold(wraps: false, voiceOverRunning: true, duration: 2) == 6)
        #expect(ToastBehavior.hold(wraps: false, voiceOverRunning: true, duration: 10) == 10)
    }

    @Test func aNegativeDuration_countsAsZero() {
        #expect(ToastBehavior.hold(wraps: false, voiceOverRunning: false, duration: -3) == 0)
        #expect(ToastBehavior.hold(wraps: false, voiceOverRunning: false, duration: -.infinity) == 0)
        #expect(ToastBehavior.hold(wraps: false, voiceOverRunning: false, duration: -0.0) == 0)
    }

    /// Whatever a caller passes, the rest is a finite time between 0 and the cap.
    @Test(arguments: [TimeInterval.infinity, 1e30, .greatestFiniteMagnitude, 61, 3_600])
    func aTooLongDuration_stopsAtTheCap(duration: TimeInterval) {
        #expect(ToastBehavior.hold(wraps: false, voiceOverRunning: false, duration: duration) == ToastBehavior.maxHold)
        #expect(ToastBehavior.hold(wraps: false, voiceOverRunning: true, duration: duration) == ToastBehavior.maxHold)
    }

    @Test func theCapItself_isKept() {
        #expect(ToastBehavior.hold(wraps: false, voiceOverRunning: false, duration: ToastBehavior.maxHold) == 60)
    }

    /// Not a number is no duration at all: the toast rests as it would have.
    @Test func aDurationThatIsNotANumber_countsAsNone() {
        #expect(ToastBehavior.hold(wraps: false, voiceOverRunning: false, duration: .nan) == 4)
        #expect(ToastBehavior.hold(wraps: true, voiceOverRunning: false, duration: .nan) == 5)
        #expect(ToastBehavior.hold(wraps: false, voiceOverRunning: true, duration: .nan) == 6)
    }

    // MARK: Sleeping

    @Test func nanoseconds_ofOrdinaryTimes() {
        #expect(ToastBehavior.nanoseconds(0.25) == 250_000_000)
        #expect(ToastBehavior.nanoseconds(4) == 4_000_000_000)
        #expect(ToastBehavior.nanoseconds(60) == 60_000_000_000)
    }

    /// `UInt64(_:)` traps on each of these. None of them may reach it.
    @Test(arguments: [TimeInterval.infinity, -.infinity, .nan, -1, -0.0, 0, 1e30, .greatestFiniteMagnitude, 1.9e10])
    func nanoseconds_ofAnythingAtAll_doesNotTrap(seconds: TimeInterval) {
        let value = ToastBehavior.nanoseconds(seconds)
        if seconds.isNaN || seconds <= 0 {
            #expect(value == 0)
        } else if seconds >= 1.9e10 {
            #expect(value == UInt64.max)
        } else {
            #expect(value > 0)
        }
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

    @Test func aDragStartsBeforeItCanDismiss() {
        #expect(ToastBehavior.swipeStartDistance < ToastBehavior.swipeDismissDistance)
    }

    // MARK: Whether a message wraps

    @Test func aMessage_taller_thanItsOwnFirstLine_wraps() {
        #expect(ToastBehavior.wraps(textHeight: 43, oneLineHeight: 21))
    }

    @Test func aMessage_asLongAsItsFirstLine_doesNotWrap() {
        #expect(!ToastBehavior.wraps(textHeight: 21, oneLineHeight: 21))
        #expect(!ToastBehavior.wraps(textHeight: 21.5, oneLineHeight: 21), "rounding is not a second line")
    }

    /// The same message is compared with itself, so a tall glyph (CJK, Arabic, an emoji) is one line when it is one
    /// line, whatever its height.
    @Test func aTallLine_isStillOneLine() {
        #expect(!ToastBehavior.wraps(textHeight: 34, oneLineHeight: 34))
        #expect(ToastBehavior.wraps(textHeight: 70, oneLineHeight: 34))
    }

    @Test func nothingMeasured_isNotWrapped() {
        #expect(!ToastBehavior.wraps(textHeight: 0, oneLineHeight: 0))
        #expect(!ToastBehavior.wraps(textHeight: 40, oneLineHeight: 0))
        #expect(!ToastBehavior.wraps(textHeight: 0, oneLineHeight: 21))
        #expect(!ToastTextMetrics().wraps)
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

    @Test func message_defaultsToTheSuccessLook_withNoDuration() {
        let plain = Auth0ToastMessage("Email verified")
        #expect(plain.style.icon != nil, "the check")
        #expect(plain.style.layout == .card)
        #expect(plain.duration == nil)
    }

    @Test func message_withAnIcon_keepsTheSuccessColours() {
        let custom = Auth0ToastMessage("Link copied", icon: Image(systemName: "doc.on.doc"), duration: 2)
        #expect(custom.style.icon != nil)
        #expect(custom.style.layout == .card)
        #expect(custom.duration == 2)
    }

    @Test func message_withANilIcon_hasNoIcon() {
        let bare = Auth0ToastMessage("Copied", icon: nil)
        #expect(bare.style.icon == nil)
        #expect(bare.style.layout == .card)
    }

    @Test func message_takesAStyle() {
        let copied = Auth0ToastMessage("Copied", style: .notice, duration: 3)
        #expect(copied.style.icon == nil)
        #expect(copied.style.layout == .compact)
        #expect(copied.duration == 3)
    }

    // MARK: Styles

    @Test func success_isTheCardWithACheck_inTheThemesColours() {
        let theme = Auth0Theme()
        let style = Auth0ToastStyle.success
        #expect(style.icon != nil)
        #expect(style.layout == .card)
        #expect(style.background(theme) == theme.colors.background.layerTop)
        #expect(style.foreground(theme) == theme.colors.text.bold)
        #expect(style.iconColor(theme) == theme.colors.foreground.success)
    }

    /// The look of the toast this replaced: the brand's primary colours, no icon, as small as its words.
    @Test func notice_isTheOlderToastsLook() {
        let theme = Auth0Theme()
        let style = Auth0ToastStyle.notice
        #expect(style.icon == nil)
        #expect(style.layout == .compact)
        #expect(style.background(theme) == theme.colors.background.primary)
        #expect(style.foreground(theme) == theme.colors.text.onPrimary)
    }

    @Test func aStyle_followsACustomTheme() {
        var theme = Auth0Theme()
        let background = DefaultAuth0BackgroundColorTokens(primary: SwiftUI.Color.red)
        theme.colors = DefaultAuth0ColorTokens(background: background)
        #expect(Auth0ToastStyle.notice.background(theme) == SwiftUI.Color.red)
    }

    @Test func aStyle_canUseAFixedColour_whateverTheTheme() {
        let style = Auth0ToastStyle(background: { _ in SwiftUI.Color.purple })
        #expect(style.background(Auth0Theme()) == SwiftUI.Color.purple)
        #expect(style.icon == nil)
    }

    @Test func theTwoLayouts_setTheTypeOfTheWords() {
        let theme = Auth0Theme()
        #expect(Auth0ToastStyle.Layout.card.typography(theme).font == theme.typography.label.font)
        #expect(Auth0ToastStyle.Layout.compact.typography(theme).font == theme.typography.helper.font)
    }

    // MARK: Which edge

    @Test func aMessage_withoutAnEdge_usesTheModifiers() {
        let message = Auth0ToastMessage("Copied")
        #expect(message.edge == nil)
        #expect(message.resolvedEdge(default: .top) == .top)
        #expect(message.resolvedEdge(default: .bottom) == .bottom)
    }

    @Test func aMessage_withAnEdge_winsOverTheModifiers() {
        let bottom = Auth0ToastMessage("Copied", style: .notice, edge: .bottom)
        #expect(bottom.edge == .bottom)
        #expect(bottom.resolvedEdge(default: .top) == .bottom)

        let top = Auth0ToastMessage("Done", icon: nil, edge: .top, duration: 2)
        #expect(top.resolvedEdge(default: .bottom) == .top)
        #expect(top.duration == 2)
        #expect(top.style.icon == nil)
    }

    @Test func atTheBottom_aSwipeDownDismisses_notUp() {
        #expect(ToastBehavior.shouldDismiss(swipe: ToastBehavior.swipeDismissDistance, edge: .bottom))
        #expect(ToastBehavior.shouldDismiss(swipe: 200, edge: .bottom))
        #expect(!ToastBehavior.shouldDismiss(swipe: -200, edge: .bottom))
        #expect(!ToastBehavior.shouldDismiss(swipe: ToastBehavior.swipeDismissDistance - 1, edge: .bottom))
    }

    @Test func atTheTop_aSwipeUpDismisses_notDown() {
        #expect(ToastBehavior.shouldDismiss(swipe: -200, edge: .top))
        #expect(!ToastBehavior.shouldDismiss(swipe: 200, edge: .top))
    }

    @Test func theToast_isOnlyPulledAwayFromItsEdge() {
        #expect(ToastBehavior.pull(-30, edge: .top) == -30)
        #expect(ToastBehavior.pull(30, edge: .top) == 0)
        #expect(ToastBehavior.pull(30, edge: .bottom) == 30)
        #expect(ToastBehavior.pull(-30, edge: .bottom) == 0)
    }

    @Test func theToast_comesInFromItsEdge() {
        #expect(ToastBehavior.slideOffset(edge: .top) == -ToastBehavior.slideDistance)
        #expect(ToastBehavior.slideOffset(edge: .bottom) == ToastBehavior.slideDistance)
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
