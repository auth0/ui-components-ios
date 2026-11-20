import SwiftUI

/// How one screen of a flow replaces another: pushed when it is deeper, popped when it is shallower, and cross-faded
/// between two ways of finishing the same step. The login and the sign-up hosts keep one each, so their screens move
/// the same way.
struct ScreenTransition {
    private var depth = 0
    /// Push (deeper) vs. pop (shallower).
    private var forward = true
    private var isSwap = false

    /// The screen shown first, which nothing has moved to.
    mutating func start(at depth: Int) {
        self.depth = depth
    }

    /// Records a move to another screen, so `transition` is the one that screen gets.
    mutating func move(to depth: Int, isSwap: Bool = false) {
        forward = depth >= self.depth
        self.isSwap = isSwap
        self.depth = depth
    }

    var transition: AnyTransition {
        if isSwap { return .opacity }
        return .asymmetric(
            insertion: .move(edge: forward ? .trailing : .leading).combined(with: .opacity),
            removal: .move(edge: forward ? .leading : .trailing).combined(with: .opacity))
    }
}

/// The animation for a change of screen, none when the user has asked for less motion.
struct ScreenMotion: DynamicProperty {
    #if !os(macOS)
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    #endif

    var animation: Animation? {
        #if !os(macOS)
        return reduceMotion ? nil : .easeInOut(duration: 0.28)
        #else
        return .easeInOut(duration: 0.28)
        #endif
    }
}

/// Clips horizontally, unbounded vertically, so a screen sliding in stays inside the sides while its background still
/// reaches under the home indicator.
struct HorizontalClip: Shape {
    func path(in rect: CGRect) -> Path {
        Path(rect.insetBy(dx: 0, dy: -10_000))
    }
}
