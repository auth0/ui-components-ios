import SwiftUI

/// A value as the server masked it, such as `(4**)***-*900` or `s***@atko.email`. Each `*` is drawn smaller and lifted
/// so its top lines up with the digits', as in the design, instead of at Inter's full asterisk size. Everything else
/// keeps the surrounding text style.
struct MaskedText: View {
    /// The text style the value is set in, so the `*` can be lifted to meet its digits.
    enum Style {
        /// 17 pt: the code screens' "From (4**)***-*900".
        case body
        /// 16 pt: a phone's row in the factor list.
        case label
    }

    let value: String
    let style: Style

    @Environment(\.auth0Theme) private var theme
    /// Lifts a `*` drawn at the helper size (13 pt) so its top meets the digits around it. In Inter the tops of digits
    /// and of `*` both sit at 0.728 em, so the lift is 0.728 × (text size − 13) pt at the default text size. Each
    /// follows Dynamic Type with its own text style.
    @ScaledMetric(relativeTo: .body) private var bodyLift: CGFloat = 2.9            // 0.728 × (17 − 13)
    @ScaledMetric(relativeTo: .callout) private var labelLift: CGFloat = 2.2        // 0.728 × (16 − 13)

    init(_ value: String, style: Style = .body) {
        self.value = value
        self.style = style
    }

    var body: some View {
        Self.runs(of: value).reduce(Text(verbatim: "")) { text, run in
            text + (run.isMask
                ? Text(verbatim: run.text).font(theme.typography.helper.font).baselineOffset(maskLift)
                : Text(verbatim: run.text))
        }
    }

    private var maskLift: CGFloat {
        switch style {
        case .body: return bodyLift
        case .label: return labelLift
        }
    }

    /// `value` split into runs of `*` and runs of everything else, in order.
    static func runs(of value: String) -> [(text: String, isMask: Bool)] {
        var runs: [(text: String, isMask: Bool)] = []
        for character in value {
            let isMask = character == "*"
            if let last = runs.last, last.isMask == isMask {
                runs[runs.count - 1].text.append(character)
            } else {
                runs.append((String(character), isMask))
            }
        }
        return runs
    }
}

#Preview {
    VStack(alignment: .leading, spacing: 12) {
        MaskedText("From (4**)***-*900")
        MaskedText("From s***@atko.email")
        MaskedText("From sarah.doe@atko.email")
        MaskedText("(4**)***-*900", style: .label)
            .auth0TextStyle(Auth0Theme().typography.label)
    }
    .auth0TextStyle(Auth0Theme().typography.body)
    .padding()
}
