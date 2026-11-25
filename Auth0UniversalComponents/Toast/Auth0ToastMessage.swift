import Foundation
import SwiftUI

/// A message for ``SwiftUI/View/auth0Toast(_:)`` to show.
///
/// Each value has its own identity, so showing the same words again is a new toast that replaces the current one
/// and restarts its time, which setting a plain `String` to the value it already has would not.
///
/// ```swift
/// @State private var toast: Auth0ToastMessage?
///
/// Button("Verify") { toast = Auth0ToastMessage("Phone number verified") }
///
/// // With an icon and a time of your own:
/// toast = Auth0ToastMessage("Link copied", icon: Image(systemName: "doc.on.doc"), duration: 2)
/// ```
public struct Auth0ToastMessage: Equatable, Identifiable {

    public let id: UUID

    /// The words to show: sentence case, no full stop, the object and the result ("Phone number verified").
    public let text: String

    /// The icon to show instead of the check, if the app set one.
    public let icon: Image?

    /// Seconds the toast rests before it fades out, if the app set it.
    public let duration: TimeInterval?

    /// - Parameters:
    ///   - text: The words to show.
    ///   - icon: Shown instead of the check. It takes the theme's success colour when it is a template image (an SF
    ///     Symbol, or an asset set to render as a template); any other image keeps its own colours. `nil` is the check.
    ///   - duration: Seconds the toast rests, after it has faded in and before it fades out, whatever the length of
    ///     the message. `nil` rests 4 s, and 1 s more for a second line. Never shorter than 6 s while VoiceOver is
    ///     running, so the announcement can be heard. Below 0 counts as 0.
    public init(_ text: String, icon: Image? = nil, duration: TimeInterval? = nil) {
        self.id = UUID()
        self.text = text
        self.icon = icon
        self.duration = duration
    }

    /// The same toast, not the same words: see the note above.
    public static func == (lhs: Auth0ToastMessage, rhs: Auth0ToastMessage) -> Bool {
        lhs.id == rhs.id
    }
}
