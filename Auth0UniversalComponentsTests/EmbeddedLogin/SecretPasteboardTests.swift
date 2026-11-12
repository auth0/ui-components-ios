@testable import Auth0UniversalComponents
import Foundation
import Testing
#if canImport(UIKit)
import UIKit
#elseif canImport(AppKit)
import AppKit
#endif

/// A secret is copied in a private pasteboard here, never the user's own.
@Suite
@MainActor
struct SecretPasteboardTests {

    @Test func theCopiedText_isOnThePasteboard() throws {
        #if canImport(UIKit)
        let pasteboard = try #require(UIPasteboard(name: UIPasteboard.Name("test.\(UUID().uuidString)"), create: true))
        defer { UIPasteboard.remove(withName: pasteboard.name) }
        SecretPasteboard.copy("YHARATFUJJKZNV5N3X1L2ZEC", to: pasteboard)
        #expect(pasteboard.string == "YHARATFUJJKZNV5N3X1L2ZEC")
        #elseif canImport(AppKit)
        let pasteboard = NSPasteboard.withUniqueName()
        defer { pasteboard.releaseGlobally() }
        SecretPasteboard.copy("YHARATFUJJKZNV5N3X1L2ZEC", to: pasteboard)
        #expect(pasteboard.string(forType: .string) == "YHARATFUJJKZNV5N3X1L2ZEC")
        #endif
    }

    @Test func aSecondCopy_replacesTheFirst() throws {
        #if canImport(UIKit)
        let pasteboard = try #require(UIPasteboard(name: UIPasteboard.Name("test.\(UUID().uuidString)"), create: true))
        defer { UIPasteboard.remove(withName: pasteboard.name) }
        SecretPasteboard.copy("FIRST", to: pasteboard)
        SecretPasteboard.copy("SECOND", to: pasteboard)
        #expect(pasteboard.string == "SECOND")
        #elseif canImport(AppKit)
        let pasteboard = NSPasteboard.withUniqueName()
        defer { pasteboard.releaseGlobally() }
        SecretPasteboard.copy("FIRST", to: pasteboard)
        SecretPasteboard.copy("SECOND", to: pasteboard)
        #expect(pasteboard.string(forType: .string) == "SECOND")
        #endif
    }

    #if canImport(AppKit) && !canImport(UIKit)
    /// The marker clipboard managers honour to keep a secret out of their history.
    @Test func onTheMac_itIsMarkedConcealed() {
        let pasteboard = NSPasteboard.withUniqueName()
        defer { pasteboard.releaseGlobally() }
        SecretPasteboard.copy("SECRET", to: pasteboard)
        #expect(pasteboard.string(forType: NSPasteboard.PasteboardType("org.nspasteboard.ConcealedType")) != nil)
    }
    #endif
}
