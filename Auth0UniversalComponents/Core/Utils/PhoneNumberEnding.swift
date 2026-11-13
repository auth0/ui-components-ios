import Foundation

/// The end of a phone number, as the code screens name it ("…ending in 0123"). Neutral on purpose: the sign-in and the
/// phone code factor each word their own sentence and need only these digits.
enum PhoneNumberEnding {

    /// What the server (or the display) puts in place of a digit it hides.
    private static let hiddenDigit: Set<Character> = ["*", "•", "X", "x"]

    /// The last digits of `number` that are really shown, at most `count`: `(4**)***-*900` gives `900` (the server
    /// shows only three), `+14155550123` gives `0123`. Digits before a hidden one are left out, since they are not
    /// the end of the number. `nil` when no digit is shown at the end (`*****`, or an empty string).
    static func digits(of number: String, count: Int = 4) -> String? {
        let shown = number.lastIndex(where: hiddenDigit.contains).map { number[number.index(after: $0)...] }
            ?? number[...]
        let digits = shown.filter { $0.isASCII && $0.isNumber }
        return digits.isEmpty ? nil : String(digits.suffix(count))
    }
}
