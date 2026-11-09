import Foundation

/// A phone number as the server masked it, made ready to show. Servers hide digits with `X` (`+1XXXXXX900`) or with
/// `*`; the screens draw `*` small and top-aligned, so every hidden digit becomes `*`.
enum PhoneMask {
    static func display(_ masked: String) -> String {
        String(masked.map { $0 == "X" || $0 == "x" ? "*" : $0 })
    }
}
