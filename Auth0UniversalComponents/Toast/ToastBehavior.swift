import CoreGraphics
import Foundation
import SwiftUI

/// How long a toast stays and when a swipe dismisses it, as plain rules a test can read.
///
/// ``ToastPresenter`` runs these rules over time; the modifier only draws.
enum ToastBehavior {

    /// The toast slides down by this much as it fades in. Skipped when Reduce Motion is on.
    static let slideDistance: CGFloat = 16

    /// Seconds to fade in.
    static let appearDuration: TimeInterval = 0.25

    /// Seconds to fade out.
    static let disappearDuration: TimeInterval = 0.2

    /// Seconds a one-line toast rests, once it is in.
    static let baseHold: TimeInterval = 4

    /// Seconds added when the message takes a second line.
    static let extraHoldForSecondLine: TimeInterval = 1

    /// While VoiceOver is running a toast rests at least this long, so it can be heard.
    static let voiceOverHold: TimeInterval = 6

    /// The longest a toast rests, whatever the app asks for. A success message that never leaves has no place here.
    static let maxHold: TimeInterval = 60

    /// A toast is one line, two at most.
    static let maxLines = 2

    /// How far a drag has to move before it starts to pull the toast.
    static let swipeStartDistance: CGFloat = 8

    /// How far the user drags the toast upward to dismiss it early.
    static let swipeDismissDistance: CGFloat = 24

    /// A message is taller than its own one-line copy by at least this much when it wraps. Absorbs rounding.
    static let wrapTolerance: CGFloat = 1

    /// Seconds the toast rests, from when it is fully in to when it starts to fade out.
    ///
    /// `duration` is the app's own time for this toast, used as it is whatever the length of the message. Without one
    /// (or with one that isn't a number), a toast rests 4 s, and 1 s more when the message wraps. Whatever was asked
    /// for is kept between 0 and ``maxHold``, and while VoiceOver is running a toast rests at least 6 s, so the
    /// announcement can be heard.
    static func hold(wraps: Bool, voiceOverRunning: Bool, duration: TimeInterval? = nil) -> TimeInterval {
        let natural = baseHold + (wraps ? extraHoldForSecondLine : 0)
        let requested = duration.flatMap { $0.isNaN ? nil : $0 } ?? natural
        let hold = min(max(requested, 0), maxHold)
        return voiceOverRunning ? max(hold, voiceOverHold) : hold
    }

    /// Whether a drag that has moved `translationHeight` points vertically (negative is up) dismisses the toast: a
    /// swipe up for a toast at the top, down for one at the bottom, back the way it came.
    static func shouldDismiss(swipe translationHeight: CGFloat, edge: VerticalEdge = .top) -> Bool {
        switch edge {
        case .top: return translationHeight <= -swipeDismissDistance
        case .bottom: return translationHeight >= swipeDismissDistance
        }
    }

    /// How far the finger has pulled the toast away from its edge, as the offset to draw it at.
    static func pull(_ translationHeight: CGFloat, edge: VerticalEdge) -> CGFloat {
        switch edge {
        case .top: return min(0, translationHeight)
        case .bottom: return max(0, translationHeight)
        }
    }

    /// Which way the toast comes in from, and goes back to: up out of the screen's edge.
    static func slideOffset(edge: VerticalEdge) -> CGFloat {
        edge == .top ? -slideDistance : slideDistance
    }

    /// Whether a message needs a second line: it is taller than the same message cut to one line. The message is
    /// compared with itself, so the answer doesn't depend on how tall a particular glyph is.
    static func wraps(textHeight: CGFloat, oneLineHeight: CGFloat) -> Bool {
        guard textHeight > 0, oneLineHeight > 0 else { return false }
        return textHeight > oneLineHeight + wrapTolerance
    }

    /// `seconds` as the nanoseconds `Task.sleep` takes. Nothing a caller can pass traps: not a number, below 0 and
    /// infinite are handled, and a value that doesn't fit stops at the largest one.
    static func nanoseconds(_ seconds: TimeInterval) -> UInt64 {
        guard !seconds.isNaN, seconds > 0 else { return 0 }
        let nanoseconds = seconds * 1_000_000_000
        return nanoseconds >= Double(UInt64.max) ? UInt64.max : UInt64(nanoseconds)
    }
}
