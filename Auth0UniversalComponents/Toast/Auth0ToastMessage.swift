import Foundation

/// A message for ``SwiftUI/View/auth0Toast(_:)`` to show.
///
/// Each value has its own identity, so showing the same words again is a new toast that replaces the current one
/// and restarts its time, which setting a plain `String` to the value it already has would not.
///
/// ```swift
/// @State private var toast: Auth0ToastMessage?
///
/// Button("Verify") { toast = Auth0ToastMessage("Phone number verified") }
/// ```
public struct Auth0ToastMessage: Equatable, Identifiable, Sendable {

    public let id: UUID

    /// The words to show: sentence case, no full stop, the object and the result ("Phone number verified").
    public let text: String

    public init(_ text: String) {
        self.id = UUID()
        self.text = text
    }
}
