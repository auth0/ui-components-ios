import Foundation
import SwiftUI

/// A message for ``SwiftUI/View/auth0Toast(_:edge:)`` to show.
///
/// Each value has its own identity, so showing the same words again is a new toast that replaces the current one
/// and restarts its time, which setting a plain `String` to the value it already has would not.
///
/// ```swift
/// @State private var toast: Auth0ToastMessage?
///
/// Button("Verify") { toast = Auth0ToastMessage("Phone number verified") }
///
/// // Another icon, or none, and a time of your own:
/// toast = Auth0ToastMessage("Link copied", icon: Image(systemName: "doc.on.doc"), duration: 2)
/// toast = Auth0ToastMessage("Copied", icon: nil)
///
/// // A different look, and the bottom of the screen:
/// toast = Auth0ToastMessage("Copied", style: .notice, edge: .bottom)
/// ```
public struct Auth0ToastMessage: Equatable, Identifiable {

    public let id: UUID

    /// The words to show: sentence case, no full stop, the object and the result ("Phone number verified").
    public let text: String

    /// How it looks.
    public let style: Auth0ToastStyle

    /// The edge of the screen it appears at, if this message sets one. `nil` uses the edge given to
    /// ``SwiftUI/View/auth0Toast(_:edge:)``.
    public let edge: VerticalEdge?

    /// Seconds the toast rests before it fades out, if the app set it. It is kept between 0 and 60 when shown, and
    /// a value that isn't a number counts as none.
    public let duration: TimeInterval?

    /// - Parameters:
    ///   - text: The words to show.
    ///   - style: How it looks. The default is the design's success toast.
    ///   - edge: The edge of the screen it appears at: `.top` or `.bottom`. It slides in from there, and a swipe away
    ///     from there dismisses it. `nil` uses the edge given to ``SwiftUI/View/auth0Toast(_:edge:)``.
    ///   - duration: Seconds the toast rests, after it has faded in and before it fades out, whatever the length of
    ///     the message. `nil` rests 4 s, and 1 s more for a second line. Never shorter than 6 s while VoiceOver is
    ///     running, so the announcement can be heard. Below 0 counts as 0, more than 60 s (`.infinity` too) is
    ///     60 s, and a value that isn't a number counts as none.
    public init(_ text: String, style: Auth0ToastStyle = .success, edge: VerticalEdge? = nil,
                duration: TimeInterval? = nil) {
        self.id = UUID()
        self.text = text
        self.style = style
        self.edge = edge
        self.duration = duration
    }

    /// The success toast with another icon, or with none (`nil`).
    ///
    /// - Parameters:
    ///   - text: The words to show.
    ///   - icon: Shown before the words, or `nil` for no icon. A template image (an SF Symbol, or an asset set to
    ///     render as a template) takes the theme's success colour; any other image keeps its own colours. VoiceOver
    ///     doesn't read the icon, so the words must say what it says.
    ///   - edge: As in ``init(_:style:edge:duration:)``.
    ///   - duration: As in ``init(_:style:edge:duration:)``.
    public init(_ text: String, icon: Image?, edge: VerticalEdge? = nil, duration: TimeInterval? = nil) {
        var style = Auth0ToastStyle.success
        style.icon = icon
        self.init(text, style: style, edge: edge, duration: duration)
    }

    /// Where this toast appears: its own edge, or `fallback`, the one given to the modifier.
    func resolvedEdge(default fallback: VerticalEdge) -> VerticalEdge {
        edge ?? fallback
    }

    /// The same toast, not the same words: see the note above.
    public static func == (lhs: Auth0ToastMessage, rhs: Auth0ToastMessage) -> Bool {
        lhs.id == rhs.id
    }
}
