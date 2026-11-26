import SwiftUI

/// A toast: a short message, with an icon if its style has one, on a raised surface.
///
/// This is the toast itself, with no placement or timing, so it can be composed anywhere. To show one over the
/// current screen, with the timing, motion and VoiceOver announcement the design asks for, use
/// ``SwiftUI/View/auth0Toast(_:edge:)``.
///
/// The look is an ``Auth0ToastStyle``: the design's success toast by default. Colours, type, spacing, radius and
/// sizes come from the active ``Auth0Theme``.
///
/// ```swift
/// Auth0ToastView("Account created")
/// Auth0ToastView("Link copied", icon: Image(systemName: "doc.on.doc"))
/// Auth0ToastView("Copied", style: .notice)
/// ```
///
/// Use the success style for a completed step that needs no decision ("Email verified"). A toast is not for errors,
/// or for anything the user must read or act on, and it holds no actions.
public struct Auth0ToastView: View {

    @Environment(\.auth0Theme) private var theme
    /// 1 at the default text size, and more as the user's text grows, so the icon keeps up with the words.
    @ScaledMetric(relativeTo: .callout) private var iconScale: CGFloat = 1

    private let message: String
    private let style: Auth0ToastStyle

    /// - Parameters:
    ///   - message: Sentence case, no full stop: the object and the result ("Phone number verified").
    ///   - style: How it looks. The default is the design's success toast.
    public init(_ message: String, style: Auth0ToastStyle = .success) {
        self.message = message
        self.style = style
    }

    /// The success toast with another icon, or with none (`nil`).
    public init(_ message: String, icon: Image?) {
        var style = Auth0ToastStyle.success
        style.icon = icon
        self.init(message, style: style)
    }

    public var body: some View {
        Group {
            switch style.layout {
            case .card: card
            case .compact: compact
            }
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(message)
    }

    /// The design's toast: full width up to a limit, at least 56 pt high, with a shadow.
    private var card: some View {
        content
            .padding(.horizontal, theme.spacing.md)
            .padding(.vertical, theme.spacing.sm)
            .frame(minHeight: theme.sizes.toastMinHeight)
            .frame(maxWidth: theme.sizes.toastMaxWidth)
            .background(
                RoundedRectangle(cornerRadius: theme.radius.button, style: .continuous)
                    .fill(style.background(theme))
                    .shadow(color: theme.colors.border.elevation.opacity(ToastShadow.contactOpacity),
                            radius: ToastShadow.contactRadius, x: 0, y: ToastShadow.contactOffset)
                    .shadow(color: theme.colors.border.elevation.opacity(ToastShadow.ambientOpacity),
                            radius: ToastShadow.ambientRadius, x: 0, y: ToastShadow.ambientOffset)
            )
    }

    /// A small toast, as big as its words.
    private var compact: some View {
        content
            .padding(theme.spacing.md)
            .background(style.background(theme), in: RoundedRectangle(cornerRadius: theme.radius.small))
    }

    private var content: some View {
        HStack(spacing: theme.spacing.sm) {
            if let icon = style.icon {
                icon
                    .resizable()
                    .scaledToFit()
                    .frame(width: theme.sizes.iconMedium * iconScale, height: theme.sizes.iconMedium * iconScale)
                    .foregroundStyle(style.iconColor(theme))
                    .accessibilityHidden(true)
            }
            words
        }
    }

    private var words: some View {
        Text(message)
            .auth0TextStyle(style.layout.typography(theme))
            .foregroundStyle(style.foreground(theme))
            .lineLimit(ToastBehavior.maxLines)
            .multilineTextAlignment(.leading)
            .modifier(FillsWidth(isOn: style.layout == .card))
            .background(measure(\.text))
            .background(oneLineCopy)
    }

    /// The same message cut to one line, unseen, to tell whether the real one needs a second. It is the message
    /// itself, so the answer holds for any script, emoji or line spacing.
    private var oneLineCopy: some View {
        Text(message)
            .auth0TextStyle(style.layout.typography(theme))
            .lineLimit(1)
            .hidden()
            .background(measure(\.oneLine))
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

/// Takes the whole width the card offers, with the words at the start, or only the words' own width.
private struct FillsWidth: ViewModifier {
    let isOn: Bool

    func body(content: Content) -> some View {
        if isOn {
            content.frame(maxWidth: .infinity, alignment: .leading)
        } else {
            content
        }
    }
}

/// The toast's two layers of shadow, from the Figma `drop-shadow` (a tight one and a soft one). The opacities are
/// fractions of the theme's elevation colour, so a custom theme still sets the colour.
private enum ToastShadow {
    static let contactRadius: CGFloat = 0.75
    static let contactOffset: CGFloat = 1
    static let contactOpacity: Double = 0.45
    static let ambientRadius: CGFloat = 6
    static let ambientOffset: CGFloat = 8
    static let ambientOpacity: Double = 0.65
}

/// The height of the message and of the same message on one line, reported up to the presenter.
struct ToastTextMetrics: Equatable {
    var text: CGFloat = 0
    var oneLine: CGFloat = 0

    var wraps: Bool { ToastBehavior.wraps(textHeight: text, oneLineHeight: oneLine) }
}

struct ToastTextMetricsKey: PreferenceKey {
    static let defaultValue = ToastTextMetrics()

    static func reduce(value: inout ToastTextMetrics, nextValue: () -> ToastTextMetrics) {
        let next = nextValue()
        if next.text > 0 { value.text = next.text }
        if next.oneLine > 0 { value.oneLine = next.oneLine }
    }
}
