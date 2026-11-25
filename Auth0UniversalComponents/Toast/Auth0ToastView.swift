import SwiftUI

/// A success toast: a check and one line of text, two at most, on a raised white surface.
///
/// This is the toast itself, with no placement or timing, so it can be composed anywhere. To show one over the
/// current screen, with the timing, motion and VoiceOver announcement the design asks for, use
/// ``SwiftUI/View/auth0Toast(_:)``.
///
/// Colours, type, spacing, radius and sizes come from the active ``Auth0Theme``.
///
/// ```swift
/// Auth0ToastView("Account created")
/// ```
///
/// Use it for a completed step that needs no decision ("Email verified"). Not for errors, or for anything the
/// user must read or act on, and it holds no actions.
public struct Auth0ToastView: View {

    @Environment(\.auth0Theme) private var theme

    private let message: String

    /// - Parameter message: Sentence case, no full stop: the object and the result ("Phone number verified").
    public init(_ message: String) {
        self.message = message
    }

    public var body: some View {
        HStack(spacing: theme.spacing.sm) {
            Image("toast_success", bundle: ResourceBundle.default)
                .renderingMode(.template)
                .resizable()
                .scaledToFit()
                .frame(width: theme.sizes.iconMedium, height: theme.sizes.iconMedium)
                .foregroundStyle(theme.colors.foreground.success)
                .accessibilityHidden(true)
            Text(message)
                .auth0TextStyle(theme.typography.label)
                .foregroundStyle(theme.colors.text.bold)
                .lineLimit(ToastBehavior.maxLines)
                .multilineTextAlignment(.leading)
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(measure(\.text))
                .background(lineReference)
        }
        .padding(.horizontal, theme.spacing.md)
        .padding(.vertical, theme.spacing.sm)
        .frame(minHeight: theme.sizes.toastMinHeight)
        .frame(maxWidth: theme.sizes.toastMaxWidth)
        .background(
            RoundedRectangle(cornerRadius: theme.radius.button, style: .continuous)
                .fill(theme.colors.background.layerTop)
                .shadow(color: theme.colors.border.elevation.opacity(0.45), radius: 0.75, x: 0, y: 1)
                .shadow(color: theme.colors.border.elevation.opacity(0.65), radius: 6, x: 0, y: 8)
        )
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(message)
    }

    /// One line of the same style, unseen, to count the message's lines against.
    private var lineReference: some View {
        Text("A")
            .auth0TextStyle(theme.typography.label)
            .lineLimit(1)
            .fixedSize()
            .hidden()
            .background(measure(\.line))
    }

    private func measure(_ field: WritableKeyPath<ToastTextMetrics, CGFloat>) -> some View {
        GeometryReader { proxy in
            Color.clear.preference(key: ToastTextMetricsKey.self, value: {
                var metrics = ToastTextMetrics()
                metrics[keyPath: field] = proxy.size.height
                return metrics
            }())
        }
    }
}

/// The height of the message and of one line of it, reported up to the presenter to count the lines.
struct ToastTextMetrics: Equatable {
    var text: CGFloat = 0
    var line: CGFloat = 0

    var lineCount: Int { ToastBehavior.lineCount(textHeight: text, lineHeight: line) }
}

struct ToastTextMetricsKey: PreferenceKey {
    static let defaultValue = ToastTextMetrics()

    static func reduce(value: inout ToastTextMetrics, nextValue: () -> ToastTextMetrics) {
        let next = nextValue()
        if next.text > 0 { value.text = next.text }
        if next.line > 0 { value.line = next.line }
    }
}
