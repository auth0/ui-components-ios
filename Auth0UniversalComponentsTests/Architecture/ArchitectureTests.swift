import Foundation
import Testing

// swiftlint:disable line_length
// (Dense rule tables and regexes read better on one line; wrapping them hides the rule.)

/// The dependency rules of the MFA design, checked against the source files. If one fails, a layer has started to
/// know something it must not.
///
///     Login ──(its own contract)──▶ (nothing)        Login knows nothing about MFA.
///     MFA Core ───────────────▶ (nothing)        The Core knows no login, no Auth0, and no specific factor.
///     Factor ─────────────────▶ Core             A factor knows the Core, not login or Auth0.
///     Adapter ────────────────▶ all of them      The only code that knows both sides.
@Suite
struct ArchitectureTests {

    private static let root = URL(fileURLWithPath: #filePath).deletingLastPathComponent().deletingLastPathComponent()
        .deletingLastPathComponent()
    private static let sources = root.appendingPathComponent("Auth0UniversalComponents")

    /// Swift files under `folder` (relative to the package sources), minus `except`, with comments removed so a note
    /// that merely mentions a word doesn't trip a rule.
    private func code(in folder: String, except: Set<String> = []) throws -> [(file: String, text: String)] {
        let base = Self.sources.appendingPathComponent(folder)
        let urls = (FileManager.default.enumerator(at: base, includingPropertiesForKeys: nil)?.allObjects as? [URL]) ?? []
        return try urls.filter { $0.pathExtension == "swift" && !except.contains($0.lastPathComponent) }.map {
            ($0.lastPathComponent, Self.strippingComments(try String(contentsOf: $0, encoding: .utf8)))
        }
    }

    private static func strippingComments(_ source: String) -> String {
        var text = source.replacingOccurrences(of: "/\\*[\\s\\S]*?\\*/", with: "", options: .regularExpression)
        text = text.replacingOccurrences(of: "//[^\\n]*", with: "", options: .regularExpression)
        return text
    }

    private func violations(in files: [(file: String, text: String)], matching pattern: String) throws -> [String] {
        let regex = try NSRegularExpression(pattern: pattern)
        return files.flatMap { file, text -> [String] in
            let range = NSRange(text.startIndex..., in: text)
            return regex.matches(in: text, range: range).compactMap { match in
                Range(match.range, in: text).map { "\(file): \(text[$0])" }
            }
        }
    }

    @Test func sourcesAreFound() throws {
        #expect(try code(in: "MFA/Core").count >= 5, "the architecture rules would pass vacuously if no files were read")
        #expect(try code(in: "EmbeddedLogin/Domain").count >= 4)
        #expect(try code(in: "MFA/Factors/Push").count >= 5)
    }

    @Test func login_knowsNothingAboutMfa() throws {
        // EmbeddedLoginView is where the two are put together; everything else in the login is blind to MFA.
        let login = try code(in: "EmbeddedLogin/Domain") + code(in: "EmbeddedLogin/Presentation",
                                                                except: ["EmbeddedLoginView.swift"])
        let found = try violations(in: login, matching: #"\bMfa\w*|\bMFA\b|\bPush[A-Z]\w*|Guardian"#)
        #expect(found.isEmpty, "\(found)")
    }

    @Test func core_knowsNeitherLoginNorAuth0NorAnySpecificFactor() throws {
        let core = try code(in: "MFA/Core") + code(in: "MFA/Configuration")
            + code(in: "MFA/Presentation", except: ["MfaScreenKit.swift"])
        // No login, no Auth0 SDK types, no additional-step types.
        let found = try violations(in: core, matching: #"import Auth0\b|\bLogin[A-Z]\w*|\bEmbedded[A-Z]\w*|NextAction|AdditionalStep"#)
        #expect(found.isEmpty, "\(found)")
        // No factor by name: it would mean the Core has to change to add one.
        let factorNames = try violations(in: core, matching: #"(?i)\b(push|guardian|otp|totp|sms|phone|email|recovery|passkey|webauthn)\w*"#)
        #expect(factorNames.isEmpty, "\(factorNames)")
    }

    @Test func core_hasNoClosedListOfFactors() throws {
        let core = try code(in: "MFA/Core") + code(in: "MFA/Configuration") + code(in: "MFA/Presentation")
        let found = try violations(in: core, matching: #"enum\s+MfaFactor(Kind|Type)\b|case\s+\.?(otp|push|phone|email|recoveryCode)\b"#)
        #expect(found.isEmpty, "\(found)")
    }

    @Test func factor_knowsTheCore_notLoginOrAuth0() throws {
        let push = try code(in: "MFA/Factors/Push")
        let found = try violations(in: push, matching: #"import Auth0\b|\bLogin[A-Z]\w*|\bEmbedded[A-Z]\w*|NextAction|AdditionalStep|EmbeddedAuth"#)
        #expect(found.isEmpty, "\(found)")
    }

    @Test func factor_reachesTheServerOnlyThroughItsOwnTransportProtocol() throws {
        let push = try code(in: "MFA/Factors/Push")
        let found = try violations(in: push, matching: #"URLSession|URLRequest|\.authorize\(|challengePush\(|verifyOob\("#)
        #expect(found.isEmpty, "\(found)")
    }

    @Test func screenKit_isTheOnlyCorePresentationFileThatNamesSharedComponents() throws {
        let presentation = try code(in: "MFA/Presentation", except: ["MfaScreenKit.swift"])
        let found = try violations(in: presentation, matching: #"Guardian|BrandSpinner|LoginPrimaryButton|embeddedScreenChrome"#)
        #expect(found.isEmpty, "\(found)")
    }
}

// swiftlint:enable line_length
