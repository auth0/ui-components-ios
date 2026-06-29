import SwiftUI

// MARK: - Generic Skeleton List

/// Repeats a skeleton row view a fixed number of times inside a `LazyVStack`, with a
/// single shimmer sweep animating across the whole list.
///
/// This is the scalable container for any list/card screen: pass the placeholder row for
/// that screen and the number of rows to fake. Because the shimmer is applied once to the
/// whole stack, every row animates in sync.
///
/// ```swift
/// SkeletonList(count: 5) {
///     AuthMethodCardSkeleton()
/// }
/// ```
struct SkeletonList<Row: View>: View {

    @Environment(\.auth0Theme) private var theme

    /// Number of placeholder rows to render.
    let count: Int
    /// Spacing between rows. Defaults to the theme's medium spacing.
    let spacing: CGFloat?
    /// Builds a single placeholder row.
    @ViewBuilder let row: () -> Row

    init(count: Int = 4,
         spacing: CGFloat? = nil,
         @ViewBuilder row: @escaping () -> Row) {
        self.count = count
        self.spacing = spacing
        self.row = row
    }

    var body: some View {
        LazyVStack(alignment: .leading, spacing: spacing ?? theme.spacing.md) {
            ForEach(0..<count, id: \.self) { _ in
                row()
            }
        }
        .shimmering()
        // The skeleton is decorative; expose a single loading announcement.
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("Loading")
    }
}

// MARK: - Card Skeleton Container

/// A themed card-shaped container that lays out arbitrary skeleton content with the same
/// padding, border, and corner radius as the SDK's real cards. Use it to keep bespoke
/// skeletons visually consistent with `MyAccountAuthMethodView` / `AuthenticatorView`.
struct SkeletonCard<Content: View>: View {

    @Environment(\.auth0Theme) private var theme

    @ViewBuilder let content: () -> Content

    var body: some View {
        content()
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(theme.spacing.lg)
            .overlay {
                RoundedRectangle(cornerRadius: theme.radius.button)
                    .stroke(theme.colors.border.regular, lineWidth: 1)
            }
    }
}

// MARK: - Auth Method Card Skeleton

/// Placeholder mirroring `MyAccountAuthMethodView`: leading icon, a title line, and a
/// trailing chevron. Used by `MyAccountAuthMethodsView` while factors load.
struct AuthMethodCardSkeleton: View {

    @Environment(\.auth0Theme) private var theme

    var body: some View {
        SkeletonCard {
            HStack(spacing: theme.spacing.md) {
                SkeletonShape(.roundedCustom(theme.radius.small))
                    .frame(width: theme.sizes.iconMedium, height: theme.sizes.iconMedium)

                SkeletonShape(.text)
                    .frame(width: 140)

                Spacer()

                SkeletonShape(.roundedCustom(theme.radius.small))
                    .frame(width: theme.sizes.iconSmall, height: theme.sizes.iconSmall)
            }
        }
    }
}

// MARK: - Saved Authenticator Card Skeleton

/// Placeholder mirroring `AuthenticatorView`: a title line, a secondary "created on"
/// line, and a trailing menu glyph. Used by `SavedAuthenticatorsView` while methods load.
struct SavedAuthenticatorCardSkeleton: View {

    @Environment(\.auth0Theme) private var theme

    var body: some View {
        SkeletonCard {
            HStack {
                VStack(alignment: .leading, spacing: theme.spacing.xs) {
                    SkeletonShape(.text)
                        .frame(width: 180)
                    SkeletonShape(.text)
                        .frame(width: 120)
                }

                Spacer()

                SkeletonShape(.roundedCustom(theme.radius.small))
                    .frame(width: theme.sizes.iconLarge, height: theme.sizes.iconLarge)
            }
        }
    }
}
