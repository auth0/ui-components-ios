import Foundation

/// Formats a phone number as it is typed, with its country's mask from `CountryCodes.json`.
enum PhoneNumberFormatter {
    /// The mask's digit slot. Everything else in a mask, like `(`, `)` and `-`, is a literal.
    static let slot: Character = "#"

    /// `text` laid out on `mask`, e.g. `4233530900` on `(###)###-####` is `(423)353-0900`.
    ///
    /// A literal appears only once a digit follows it, so a partly typed number reads naturally (`(423)35`). Digits
    /// past the mask are kept at the end, so nothing typed is lost. With no mask, or a number typed with its own `+`,
    /// `text` comes back as it is.
    static func format(_ text: String, mask: String?) -> String {
        guard let mask, !text.trimmingCharacters(in: .whitespaces).hasPrefix("+") else { return text }
        let typed = digits(text)
        var next = typed.startIndex
        var result = ""
        for character in mask {
            guard next < typed.endIndex else { break }
            if character == slot {
                result.append(typed[next])
                next = typed.index(after: next)
            } else {
                result.append(character)
            }
        }
        return result + typed[next...]
    }

    /// How many digits a number on `mask` has.
    static func digitCount(of mask: String) -> Int {
        mask.filter { $0 == slot }.count
    }

    static func digits(_ text: String) -> String {
        String(text.filter { $0.isASCII && $0.isNumber })
    }
}
