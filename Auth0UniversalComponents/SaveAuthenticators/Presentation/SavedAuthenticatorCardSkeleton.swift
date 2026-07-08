import SwiftUI

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
