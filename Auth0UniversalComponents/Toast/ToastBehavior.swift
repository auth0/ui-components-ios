import CoreGraphics
import Foundation

/// How long a toast stays and when a swipe dismisses it, as plain rules a test can read.
///
/// The presenter (``Auth0ToastModifier``) only schedules and animates; it decides nothing itself.
enum ToastBehavior {

    /// The toast slides down by this much as it fades in. Skipped when Reduce Motion is on.
    static let slideDistance: CGFloat = 16

    /// Seconds to fade in.
    static let appearDuration: TimeInterval = 0.25

    /// Seconds to fade out.
    static let disappearDuration: TimeInterval = 0.2

    /// Seconds a one-line toast rests, once it is in.
    static let baseHold: TimeInterval = 4

    /// Seconds added for each line after the first.
    static let extraHoldPerLine: TimeInterval = 1

    /// While VoiceOver is running a toast rests at least this long, so it can be heard.
    static let voiceOverHold: TimeInterval = 6

    /// A toast is one line, two at most.
    static let maxLines = 2

    /// How far the user drags the toast upward to dismiss it early.
    static let swipeDismissDistance: CGFloat = 24

    /// Seconds the toast rests, from when it is fully in to when it starts to fade out.
    static func hold(lines: Int, voiceOverRunning: Bool) -> TimeInterval {
        let shown = min(max(lines, 1), maxLines)
        let hold = baseHold + extraHoldPerLine * TimeInterval(shown - 1)
        return voiceOverRunning ? max(hold, voiceOverHold) : hold
    }

    /// Whether a drag that has moved `translationHeight` points vertically (negative is up) dismisses the toast.
    static func shouldDismiss(swipe translationHeight: CGFloat) -> Bool {
        translationHeight <= -swipeDismissDistance
    }

    /// The number of lines a message takes, from its height and the height of one line in the same style.
    static func lineCount(textHeight: CGFloat, lineHeight: CGFloat) -> Int {
        guard lineHeight > 0, textHeight > 0 else { return 1 }
        return min(max(Int((textHeight / lineHeight).rounded()), 1), maxLines)
    }
}
