@testable import Auth0UniversalComponents
import Testing

/// The end of a number the code screens name ("ending in 0123"): only digits the server really shows.
@Suite
struct PhoneNumberEndingTests {

    @Test(arguments: [
        ("+14155550123", "0123"),            // typed in full: the last four
        ("+1 (415) 555-0123", "0123"),       // separators don't count
        ("(4**)***-*900", "900"),            // the server shows three, so three
        ("+1******900", "900"),              // hidden with `X`, shown by PhoneMask as `*`
        ("+1XXXXXX0123", "0123"),            // or still `X`
        ("••• 9239", "9239"),                // the list's bullet form
        ("***-**-12", "12"),
        ("+4412", "4412")
    ])
    func theLastShownDigits(number: String, expected: String) {
        #expect(PhoneNumberEnding.digits(of: number) == expected)
    }

    @Test func digitsBeforeAHiddenOneAreNotTheEnd() {
        // Only "9" and "0" are shown after the last hidden digit; the "4" before it is not the end of the number.
        #expect(PhoneNumberEnding.digits(of: "(4**)*9*0") == "0")
    }

    @Test(arguments: ["", "*****", "••••", "XXXX", "(***) ***-****", "no digits"])
    func nothingShown_isNil(number: String) {
        #expect(PhoneNumberEnding.digits(of: number) == nil)
    }

    @Test func theCountCanBeChosen() {
        #expect(PhoneNumberEnding.digits(of: "+14155550123", count: 2) == "23")
        #expect(PhoneNumberEnding.digits(of: "+14155550123", count: 20) == "14155550123")
    }
}
