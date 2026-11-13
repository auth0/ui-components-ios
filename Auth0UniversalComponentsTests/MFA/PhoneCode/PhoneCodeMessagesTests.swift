@testable import Auth0UniversalComponents
import Testing

/// The words under the phone code screen's title: a texted code and a call both name the end of the number.
@Suite
struct PhoneCodeMessagesTests {

    private let words = PhoneCodeChallengeMessages.defaults

    @Test func aTextedCode_namesTheEndOfTheNumber() {
        #expect(words.subtitle(number: "(4**)***-*900", delivery: .text) == "Sent to the phone number ending in 900")
        #expect(words.subtitle(number: "+1******0900", delivery: .text) == "Sent to the phone number ending in 0900")
    }

    @Test func aTextedCode_toANumberWithNoDigitsShown_saysItWasTexted() {
        #expect(words.subtitle(number: "*****", delivery: .text) == "We texted a code to your phone.")
        #expect(words.subtitle(number: "", delivery: .text) == "We texted a code to your phone.")
    }

    @Test func aCall_namesTheEndOfTheNumber() {
        #expect(words.subtitle(number: "(4**)***-*900", delivery: .voice)
                == "Calling your phone number ending in 900")
        #expect(words.subtitle(number: "+1******0900", delivery: .voice)
                == "Calling your phone number ending in 0900")
    }

    @Test func aCall_toANumberWithNoDigitsShown_saysItIsCalling() {
        #expect(words.subtitle(number: "*****", delivery: .voice) == "We're calling your phone with a code.")
        #expect(words.subtitle(number: "", delivery: .voice) == "We're calling your phone with a code.")
    }

    @Test func theAppCanStillWordItsOwn() {
        let changed = MfaMessages.default.with { $0.phoneCodeChallenge.text.description = { "Code sent to \($0)." } }
        #expect(changed.phoneCodeChallenge.subtitle(number: "(4**)***-*900", delivery: .text)
                == "Code sent to (4**)***-*900.")
    }
}
