import Foundation

/// Light E.164 check; the server is the source of truth. Spaces, dashes and brackets are allowed while typing. Digits
/// may be in any script (Arabic-Indic, full-width, …); other numerals such as `½` are rejected, never dropped.
enum PhoneNumberValidator {
    /// E.164 allows at most 15 digits, country code included.
    private static let maxDigits = 15
    /// Shorter than this is a typo, not a number. Only used for countries without a mask.
    private static let minNationalDigits = 4
    /// Dial codes (digits only) of countries whose numbers really start with 0: Italy and San Marino, and the plans of
    /// Côte d'Ivoire, Benin and Gabon. Anywhere else a leading 0 is the trunk prefix, which isn't dialled from abroad.
    private static let zeroIsPartOfTheNumber: Set<String> = ["39", "378", "225", "229", "241"]

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
        var national = PhoneNumberFormatter.digits(typed)
        let isInternational = PhoneNumberFormatter.isInternational(typed)
        if let mask, !isInternational {
            guard national.count == PhoneNumberFormatter.digitCount(of: mask) else { return nil }
        } else {
            if !isInternational {
                guard let local = withoutTrunkZero(national, dialCode: dialCode) else { return nil }
                national = local
            }
            guard national.count >= minNationalDigits else { return nil }
        }
        let full = isInternational ? national : PhoneNumberFormatter.digits(dialCode) + national
        guard full.count <= maxDigits else { return nil }
        return "+" + full
    }

    /// `national` as it's dialled from abroad: `07700 900123` is `+44 7700 900123`. `nil` for `00…`, an international
    /// prefix and not a number.
    private static func withoutTrunkZero(_ national: String, dialCode: String) -> String? {
        guard national.hasPrefix("0"),
              !zeroIsPartOfTheNumber.contains(PhoneNumberFormatter.digits(dialCode)) else { return national }
        let rest = String(national.dropFirst())
        return rest.hasPrefix("0") ? nil : rest
    }
}
