@testable import Auth0UniversalComponents
import Testing

/// How a masked value is split, so each `*` can be drawn smaller and top-aligned.
@Suite
struct MaskedTextTests {

    @Test func aMaskedNumber_splitsIntoMaskAndTextRuns() {
        let runs = MaskedText.runs(of: "From (4**)***-*900")
        #expect(runs.map(\.text) == ["From (4", "**", ")", "***", "-", "*", "900"])
        #expect(runs.map(\.isMask) == [false, true, false, true, false, true, false])
    }

    @Test func aMaskedEmail_splitsTheSameWay() {
        let runs = MaskedText.runs(of: "s***@atko.email")
        #expect(runs.map(\.text) == ["s", "***", "@atko.email"])
    }

    @Test func textWithoutMask_isOneRun() {
        let runs = MaskedText.runs(of: "From sarah.doe@atko.email")
        #expect(runs.count == 1)
        #expect(runs.first?.isMask == false)
    }

    @Test func nothing_isNoRuns() {
        #expect(MaskedText.runs(of: "").isEmpty)
    }

    /// Nothing is lost or reordered.
    @Test(arguments: ["(4**)***-*900", "****", "*a*", "+1 ••• 9239"])
    func theRuns_joinBackToTheValue(_ value: String) {
        #expect(MaskedText.runs(of: value).map(\.text).joined() == value)
    }
}

/// A phone mask is made ready to show: every hidden digit becomes `*`, whichever letter the server hid it with.
@Suite
struct PhoneMaskTests {

    @Test(arguments: [
        ("+1XXXXXX900", "+1******900"),
        ("(4xx)xxx-x900", "(4**)***-*900"),
        ("(4**)***-*900", "(4**)***-*900"),
        ("+44 7XXX XXX123", "+44 7*** ***123"),
        ("", "")
    ])
    func hiddenDigits_becomeAsterisks(_ masked: String, _ shown: String) {
        #expect(PhoneMask.display(masked) == shown)
    }
}
