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
    }
}
