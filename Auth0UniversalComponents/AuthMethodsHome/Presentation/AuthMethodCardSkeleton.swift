import SwiftUI

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
