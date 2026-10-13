import SwiftUI

// Building blocks for the status screens.

/// Centered content with a bottom-anchored actions row.
struct FlowScaffold<Content: View, Actions: View>: View {
    @ViewBuilder var content: () -> Content
    @ViewBuilder var actions: () -> Actions

    var body: some View {
        VStack(spacing: 14) {
            Spacer()
            content()
            Spacer()
            actions()
        }
        .padding(.horizontal, 28)
        .padding(.bottom, 40)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}

/// Centered title with an optional secondary message.
struct StatusText: View {
    let title: String
    var message: String?

    var body: some View {
        Text(title)
            .font(.title).fontWeight(.semibold)
            .multilineTextAlignment(.center)
        if let message {
            Text(message)
                .font(.body).foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
        }
    }
}

/// Full-width capsule that inverts with the color scheme.
struct PrimaryPillButton: View {
    let title: String
    let action: () -> Void
    @Environment(\.colorScheme) private var scheme

    var body: some View {
        Button(action: action) {
            Text(title)
                .font(.headline)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 17)
        }
        .foregroundStyle(scheme == .dark ? Color.black : Color.white)
        .background(scheme == .dark ? Color.white : Color.black, in: Capsule())
        .buttonStyle(.plain)
    }
}

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

/// Thin rotating spinner. Clock-driven so it doesn't pick up the screen's push animation.
struct BrandSpinner: View {
    @Environment(\.auth0Theme) private var theme

    private static let period: TimeInterval = 0.9

    var body: some View {
        TimelineView(.animation) { timeline in
            let elapsed = timeline.date.timeIntervalSinceReferenceDate
            Circle()
                .trim(from: 0.05, to: 0.85)
                .stroke(theme.colors.text.bold, style: StrokeStyle(lineWidth: 2.5, lineCap: .round))
                .frame(width: 40, height: 40)
                .rotationEffect(.degrees(elapsed.truncatingRemainder(dividingBy: Self.period) / Self.period * 360))
        }
        .accessibilityLabel("Loading")
    }
}
