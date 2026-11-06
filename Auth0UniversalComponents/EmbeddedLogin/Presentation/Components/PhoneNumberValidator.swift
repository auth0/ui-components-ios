import Foundation

/// Light E.164 check; the server is the source of truth. Spaces, dashes and brackets are allowed while typing. Digits
/// may be in any script (Arabic-Indic, full-width, …); other numerals such as `½` are rejected, never dropped.
enum PhoneNumberValidator {
    /// E.164 allows at most 15 digits, country code included.
    private static let maxDigits = 15
    /// Shorter than this is a typo, not a number. Only used for countries without a mask.
    private static let minNationalDigits = 4

    /// The full number, e.g. `+14155550123`, or `nil` if it can't be one.
    ///
    /// - Parameters:
    ///   - dialCode: The picked country's code, like `"+1"`.
    ///   - number: What the user typed. A number that starts with `+` is taken as already international, and the
    ///     picked country is ignored.
    ///   - mask: The country's format. When there is one, the number must fill it exactly.
    static func e164(dialCode: String, number: String, mask: String? = nil) -> String? {
        let typed = number.trimmingCharacters(in: .whitespacesAndNewlines)
        guard typed.allSatisfy({ PhoneNumberFormatter.digit($0) != nil || " -().+".contains($0) }) else { return nil }
        let national = PhoneNumberFormatter.digits(typed)
        let isInternational = typed.hasPrefix("+")
        if let mask, !isInternational {
            guard national.count == PhoneNumberFormatter.digitCount(of: mask) else { return nil }
        } else {
            guard national.count >= minNationalDigits else { return nil }
        }
        let full = isInternational ? national : PhoneNumberFormatter.digits(dialCode) + national
        guard full.count <= maxDigits else { return nil }
        return "+" + full
    }
}
