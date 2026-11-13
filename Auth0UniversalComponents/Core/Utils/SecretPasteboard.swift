import Foundation
#if canImport(UIKit)
import UIKit
import UniformTypeIdentifiers
#elseif canImport(AppKit)
import AppKit
#endif

/// Copies something secret, like a recovery code, to the pasteboard in the careful way: it doesn't travel to the user's
/// other devices, and where the system allows it, it doesn't stay.
enum SecretPasteboard {
    /// How long a copied secret stays on the pasteboard, where the system can take it back.
    static let lifetime: TimeInterval = 120

    #if canImport(UIKit)
    static func copy(_ text: String, to pasteboard: UIPasteboard = .general) {
        pasteboard.setItems([[UTType.plainText.identifier: text]],
                            options: [.localOnly: true, .expirationDate: Date().addingTimeInterval(lifetime)])
    }
    #elseif canImport(AppKit)
    static func copy(_ text: String, to pasteboard: NSPasteboard = .general) {
        pasteboard.clearContents()
        pasteboard.setString(text, forType: .string)
        // The marker clipboard managers honour to leave a secret out of their history.
        pasteboard.setString("", forType: NSPasteboard.PasteboardType("org.nspasteboard.ConcealedType"))
    }
    #endif
}
