import SwiftUI

/// Thin rotating spinner. Clock-driven so it doesn't pick up the screen's push animation.
struct BrandSpinner: View {
    /// Diameter of the ring's path; the stroke extends half its width beyond it.
    var diameter: CGFloat = 40

    @Environment(\.auth0Theme) private var theme

    private static let period: TimeInterval = 0.9

    var body: some View {
        TimelineView(.animation) { timeline in
            let elapsed = timeline.date.timeIntervalSinceReferenceDate
            Circle()
                .trim(from: 0.05, to: 0.85)
                .stroke(theme.colors.text.bold, style: StrokeStyle(lineWidth: 2.5, lineCap: .round))
                .frame(width: diameter, height: diameter)
                .rotationEffect(.degrees(elapsed.truncatingRemainder(dividingBy: Self.period) / Self.period * 360))
        }
        .accessibilityLabel("Loading")
    }
}
