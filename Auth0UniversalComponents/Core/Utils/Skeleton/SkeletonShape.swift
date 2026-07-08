import SwiftUI

// MARK: - Skeleton Placeholder Primitive

/// A single themed placeholder block used to compose skeleton loading layouts.
///
/// `SkeletonShape` is the atomic building block of the skeleton system. It renders a
/// solid, theme-coloured shape sized by the standard `.frame(...)` modifiers and is
/// meant to stand in for a piece of real content — a line of text, an avatar, an icon,
/// a thumbnail — while data loads.
///
/// Compose several shapes inside stacks to mirror the layout of a real view, then wrap
/// the composition in ``SwiftUI/View/shimmering(active:)`` to animate them together:
///
/// ```swift
/// HStack(spacing: theme.spacing.md) {
///     SkeletonShape(.circle).frame(width: 40, height: 40)
///     VStack(alignment: .leading, spacing: theme.spacing.xs) {
///         SkeletonShape(.text).frame(width: 160)
///         SkeletonShape(.text).frame(width: 100)
///     }
/// }
/// .shimmering()
/// ```
struct SkeletonShape: View {

    /// The geometry of a placeholder block.
    enum Kind {
        /// A pill-height line standing in for a single line of text. Defaults to a
        /// fixed height so callers only need to specify a width.
        case text
        /// A rounded rectangle using the theme's `button` corner radius — for cards,
        /// thumbnails, and large surfaces.
        case rounded
        /// A rounded rectangle using a custom corner radius.
        case roundedCustom(CGFloat)
        /// A perfect circle — for avatars and circular icons. Size it with `.frame`.
        case circle
        /// A fully rounded capsule — for tags, chips, and short labels.
        case capsule
    }

    // MARK: - Environment Variables
    @Environment(\.auth0Theme) private var theme
    @Environment(\.colorScheme) private var colorScheme

    // MARK: - Properties
    let kind: Kind

    /// Creates a placeholder block of the given `kind`.
    /// - Parameter kind: The geometry of the placeholder. Defaults to `.text`.
    init(_ kind: Kind = .text) {
        self.kind = kind
    }

    // MARK: - Main body
    var body: some View {
        shape
            // Resting colour adapts to light/dark mode; the shimmer sweep is layered on
            // top by `.shimmering()` when the shape is part of a loading layout.
            .fill(SkeletonPalette(colorScheme: colorScheme).base)
            .modifier(DefaultHeight(kind: kind))
    }

    // MARK: - Shape Resolution
    /// Erases the kind-specific shape so a single `body` can fill any of them.
    private var shape: AnyShape {
        switch kind {
        case .text:
            return AnyShape(RoundedRectangle(cornerRadius: theme.radius.small, style: .continuous))
        case .rounded:
            return AnyShape(RoundedRectangle(cornerRadius: theme.radius.button, style: .continuous))
        case .roundedCustom(let radius):
            return AnyShape(RoundedRectangle(cornerRadius: radius, style: .continuous))
        case .circle:
            return AnyShape(Circle())
        case .capsule:
            return AnyShape(Capsule(style: .continuous))
        }
    }
}

// MARK: - Default Height

/// Applies a sensible default height for `.text` placeholders so callers only need to
/// specify a width. All other kinds are left to be sized entirely by the caller.
private struct DefaultHeight: ViewModifier {
    let kind: SkeletonShape.Kind

    func body(content: Content) -> some View {
        switch kind {
        case .text:
            content.frame(height: 14)
        default:
            content
        }
    }
}

// MARK: - Redaction Modifier

/// A modifier that replaces a view's real content with a shimmering skeleton overlay
/// while `active` is `true`, falling back to the real content otherwise.
///
/// This is the most extensible entry point into the skeleton system: any existing view
/// can be turned into a loading placeholder without authoring a bespoke skeleton, by
/// reusing the view's own geometry as the placeholder shape.
private struct SkeletonRedaction: ViewModifier {
    
    // MARK: - Theme
    @Environment(\.auth0Theme) private var theme
    
    // MARK: - Properties
    let isActive: Bool

    func body(content: Content) -> some View {
        if isActive {
            content
                // Hide the real content but keep its layout footprint…
                .opacity(0)
                .overlay(
                    // …and lay a shape of the same size on top to shimmer.
                    SkeletonShape(.rounded)
                        .shimmering()
                )
        } else {
            content
        }
    }
}

extension View {

    /// Replaces this view with a shimmering skeleton placeholder of the same size while
    /// `active` is `true`.
    ///
    /// Use this when you want a quick loading state for an existing view without
    /// hand-building a matching skeleton layout. For pixel-faithful list/card skeletons,
    /// prefer composing ``SkeletonShape`` primitives directly.
    ///
    /// ```swift
    /// AvatarView(url: user?.avatar)
    ///     .skeleton(isLoading)
    /// ```
    ///
    /// - Parameter active: When `true`, the view renders as a shimmering placeholder.
    /// - Returns: A view that shows a skeleton while `active` is `true`, otherwise its
    ///   real content.
    func skeleton(_ active: Bool) -> some View {
        modifier(SkeletonRedaction(isActive: active))
    }
}
