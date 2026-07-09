import SwiftUI

// MARK: - Skeleton Palette

/// Resolves the two greys used by every skeleton placeholder for the current colour
/// scheme.
///
/// Skeletons need a placeholder that is clearly visible against the page background in
/// **both** light and dark mode, plus a brighter "highlight" tone for the moving sweep.
/// The SDK's layer tokens don't provide enough separation for this (in light mode the
/// card layer and the page background are nearly the same white), so the skeleton system
/// uses its own purpose-built greys that adapt to `colorScheme`.
struct SkeletonPalette {

    /// The resting colour of a placeholder block.
    let base: Color
    /// The brighter tone that sweeps across during the shimmer.
    let highlight: Color

    init(colorScheme: ColorScheme) {
        switch colorScheme {
        case .dark:
            base = Color(white: 0.22)
            highlight = Color(white: 0.34)
        default:
            base = Color(white: 0.88)
            highlight = Color(white: 0.97)
        }
    }
}

// MARK: - Shimmer Engine

/// A reusable view modifier that sweeps an animated highlight across its content,
/// producing the classic "shimmer" loading effect.
///
/// `Shimmer` is the low-level animation engine that powers every skeleton placeholder
/// in the SDK. It is intentionally content-agnostic: it masks itself with whatever view
/// it is attached to, so it can animate the highlight over a single ``SkeletonShape``,
/// a composed skeleton card, or any arbitrary opaque view.
///
/// The sweep is rendered as an opaque `base → highlight → base` gradient masked to the
/// content's own shape. Because the band fades back to the base colour at both edges,
/// the highlight glides seamlessly with no hard rectangle — and it stays visible in both
/// light and dark mode regardless of the underlying page colour.
///
/// Prefer the ``SwiftUI/View/shimmering(active:)`` convenience modifier over
/// instantiating this type directly.
///
/// ## Accessibility
///
/// The sweeping animation is automatically disabled when the system **Reduce Motion**
/// setting is enabled. In that case the content renders as a static placeholder so the
/// loading state is still communicated without motion.
struct Shimmer: ViewModifier {

    // MARK: - Environment Variables
    @Environment(\.colorScheme) private var colorScheme
    #if !os(macOS)
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    #endif

    /// When `false`, the modifier is a no-op and renders its content unchanged.
    let isActive: Bool

    /// Normalised sweep position, animated `0 → 1` on repeat. Drives the horizontal
    /// offset of the highlight band.
    @State private var phase: CGFloat = 0

    /// Duration of a single sweep, in seconds.
    private let duration: Double = 1.3

    func body(content: Content) -> some View {
        if isActive {
            let palette = SkeletonPalette(colorScheme: colorScheme)
            content
                .overlay(highlight(palette: palette, content: content))
                .onAppear { startAnimation() }
        } else {
            content
        }
    }

    // MARK: - Highlight Band

    /// The moving highlight, masked by the content's own shape so the sweep only appears
    /// over the placeholder geometry rather than as a rectangle around it.
    ///
    /// The band is a `base → highlight → base` gradient positioned with **relative**
    /// `UnitPoint`s (measured 0→1 across the content, independent of its pixel size).
    /// `phase` drives both endpoints in lockstep, sliding the band one full content-width
    /// left-to-right per sweep:
    ///
    /// - At `phase == 0` the band sits entirely off the leading edge (`start == -1`).
    /// - At `phase == 1` it has travelled entirely off the trailing edge (`end == 2`).
    ///
    /// Because the two outer stops are the base colour, the highlight fades in and out at
    /// the edges instead of appearing as a hard rectangle, so the sweep reads as seamless.
    @ViewBuilder
    private func highlight<C: View>(palette: SkeletonPalette, content: C) -> some View {
        LinearGradient(
            gradient: Gradient(colors: [palette.base, palette.highlight, palette.base]),
            startPoint: UnitPoint(x: phase * 2 - 1, y: 0.5),
            endPoint: UnitPoint(x: phase * 2, y: 0.5)
        )
        .mask(content)
        .allowsHitTesting(false)
    }

    // MARK: - Animation

    private func startAnimation() {
        #if !os(macOS)
        guard reduceMotion == false else { return }
        #endif
        phase = 0
        withAnimation(.linear(duration: duration).repeatForever(autoreverses: false)) {
            phase = 1
        }
    }
}

// MARK: - View Convenience

extension View {

    /// Sweeps an animated shimmer highlight across this view to indicate loading.
    ///
    /// Attach this to any placeholder view — a single ``SkeletonShape``, a composed
    /// skeleton card, or a list of them — to animate a moving highlight over its
    /// geometry. The highlight is masked to the view's own shape.
    ///
    /// ```swift
    /// SkeletonShape(.rounded)
    ///     .frame(height: 20)
    ///     .shimmering()
    /// ```
    ///
    /// - Parameter active: When `false`, the modifier renders the view unchanged with
    ///   no animation. Defaults to `true`. The sweep is also suppressed automatically
    ///   when **Reduce Motion** is enabled.
    /// - Returns: A view that shimmers while `active` is `true`.
    func shimmering(active: Bool = true) -> some View {
        modifier(Shimmer(isActive: active))
    }
}
