import CoreText
import Foundation

/// Registers the Inter static font files bundled with Auth0UIComponents.
///
/// **Why this exists:**
/// SPM resource bundles do not auto-register fonts — `CTFontManagerRegisterFontsForURL`
/// must be called before `Font.custom(_:size:)` can resolve the typefaces.
///
/// Three weights are registered: Regular (400), Medium (500), and SemiBold (600).
enum Auth0FontRegistration {

    /// Thread-safe one-time font registration via Swift's static-let guarantee.
    private static let _registered: Bool = {
        let bundle = ResourceBundle.default
        let fonts = [
            "Inter-Regular",
            "Inter-Medium",
            "Inter-SemiBold"
        ]
        for name in fonts {
            // SPM bundle: fonts are in Fonts/Inter/; Xcode framework bundle: fonts are at the root.
            let url = bundle.url(forResource: name, withExtension: "ttf", subdirectory: "Fonts/Inter")
                   ?? bundle.url(forResource: name, withExtension: "ttf")
            guard let url else { continue }
            CTFontManagerRegisterFontsForURL(url as CFURL, .process, nil)
        }
        return true
    }()

    /// Ensures all Inter weight fonts are registered. Safe to call many times.
    static func registerIfNeeded() {
        _ = _registered
    }
}
