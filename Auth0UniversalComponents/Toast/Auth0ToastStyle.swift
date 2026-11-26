import SwiftUI

/// How a toast looks: its icon, colours and shape. ``success`` is the design's toast, and ``notice`` is a small dark
/// one with no icon. Start from either and change what you need, or build your own:
///
/// ```swift
/// var style = Auth0ToastStyle.success
/// style.icon = Image(systemName: "doc.on.doc")
///
/// let warning = Auth0ToastStyle(icon: Image(systemName: "exclamationmark.triangle"),
///                               iconColor: { _ in .orange })
/// ```
///
/// Colours are given as a closure that takes the active ``Auth0Theme``, so a style follows a custom theme and dark
/// mode, or ignores both by returning a fixed colour.
public struct Auth0ToastStyle {

    /// How big and how heavy the toast is.
    public enum Layout: Sendable {
        /// The design's toast: full width up to a limit, at least 56 pt high, a raised surface with a shadow.
        case card
        /// A small toast that is only as big as its words: smaller type and corners, no shadow.
        case compact
    }

    /// Shown before the words, or `nil` for none. A template image (an SF Symbol, or an asset set to render as a
    /// template) takes ``iconColor``; any other image keeps its own colours. VoiceOver doesn't read the icon, so the
    /// words must say what it says.
    public var icon: Image?

    /// The colour of a template icon.
    public var iconColor: (Auth0Theme) -> Color

    /// The surface behind the words.
    public var background: (Auth0Theme) -> Color

    /// The words.
    public var foreground: (Auth0Theme) -> Color

    public var layout: Layout

    /// With no arguments: no icon, the card's surface and words in the theme's colours.
    public init(icon: Image? = nil,
                iconColor: @escaping (Auth0Theme) -> Color = { $0.colors.foreground.success },
                background: @escaping (Auth0Theme) -> Color = { $0.colors.background.layerTop },
                foreground: @escaping (Auth0Theme) -> Color = { $0.colors.text.bold },
                layout: Layout = .card) {
        self.icon = icon
        self.iconColor = iconColor
        self.background = background
        self.foreground = foreground
        self.layout = layout
    }

    /// The design's success toast: a green check on a raised white surface (dark in dark mode).
    public static var success: Auth0ToastStyle {
        Auth0ToastStyle(icon: Image("toast_success", bundle: ResourceBundle.default))
    }

    /// A small toast in the brand's primary colours, with no icon: "Copied".
    public static var notice: Auth0ToastStyle {
        Auth0ToastStyle(background: { $0.colors.background.primary },
                        foreground: { $0.colors.text.onPrimary },
                        layout: .compact)
    }
}

extension Auth0ToastStyle.Layout {

    /// The type of the words.
    func typography(_ theme: Auth0Theme) -> Auth0TextStyle {
        switch self {
        case .card: return theme.typography.label
        case .compact: return theme.typography.helper
        }
    }
}
