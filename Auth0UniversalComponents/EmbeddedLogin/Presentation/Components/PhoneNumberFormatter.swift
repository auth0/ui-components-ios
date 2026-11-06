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

    /// A decimal digit in any script (ASCII, Arabic-Indic, full-width, Devanagari, …) as its ASCII digit. Other
    /// numerals (½, ④, ², 五, Ⅷ) aren't digits: nil. The validator uses this too, so the two always agree.
    static func digit(_ character: Character) -> Character? {
        guard character.unicodeScalars.count == 1, let scalar = character.unicodeScalars.first,
              scalar.properties.numericType == .decimal, let value = character.wholeNumberValue else { return nil }
        return Character(String(value))
    }

    /// The digits in `text`, as ASCII digits.
    static func digits(_ text: String) -> String {
        String(text.compactMap(digit))
    }
}
