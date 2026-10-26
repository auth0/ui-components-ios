import SwiftUI

/// Soft brand-colored glow along the bottom edge.
struct BrandGradient: View {
    @Environment(\.auth0Theme) private var theme

    var body: some View {
        GeometryReader { geo in
            VStack(spacing: 0) {
                Spacer()
                LinearGradient(
                    stops: [
                        .init(color: theme.colors.background.layerBase, location: 0.00),
                        .init(color: theme.colors.background.accent.opacity(0.35), location: 0.25),
                        .init(color: theme.colors.background.primary.opacity(0.25), location: 0.52),
                        .init(color: theme.colors.background.accent.opacity(0.20), location: 0.75),
                        .init(color: theme.colors.background.layerBase, location: 1.00),
                    ],
                    startPoint: UnitPoint(x: 0.24, y: 0.22),
                    endPoint: UnitPoint(x: 0.95, y: 0.24)
                )
                .frame(height: geo.size.height / 4)
                .blur(radius: 155)
            }
            .ignoresSafeArea()
        }
    }
}
