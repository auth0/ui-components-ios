import SwiftUI

/// Collects the phone number the code is texted to. The country starts as the device's region, and Continue sits at
/// the bottom of the screen.
public struct LoginPhoneScreen: View {
    let title: String
    let isLoading: Bool
    /// Server-side error (e.g. code couldn't be sent). Cleared from view once the user edits.
    let errorMessage: String?
    let onContinue: (String) -> Void

    @Environment(\.auth0Theme) private var theme
    @State private var number: String
    @State private var country: Country?

    /// - Parameters:
    ///   - number: Pre-fills the field. An E.164 number (`+14155550123`) picks its country and fills in the rest.
    ///   - onContinue: Receives the number in E.164 form, e.g. `+14155550123`.
    public init(title: String = "Enter your phone number to get started",
                number: String = "",
                isLoading: Bool = false,
                errorMessage: String? = nil,
                onContinue: @escaping (String) -> Void) {
        self.title = title
        // Set before the first render, so the form doesn't take it for an edit and hide `errorMessage`.
        let entry = LoginPhoneForm.startingEntry(for: number)
        self._country = State(initialValue: entry.country)
        self._number = State(initialValue: entry.number)
        self.isLoading = isLoading
        self.errorMessage = errorMessage
        self.onContinue = onContinue
    }

    public var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            LoginScreenHeader(title: title)
            LoginPhoneForm(country: $country, number: $number, isLoading: isLoading, serverError: errorMessage,
                           pinsContinueToBottom: true, onContinue: onContinue)
        }
        .embeddedScreenChrome(theme: theme, scrolls: true)
    }
}

#Preview("Phone") {
    LoginPhoneScreen { _ in }
}

#Preview("Phone – send failed") {
    LoginPhoneScreen(number: "+14233530900", errorMessage: AuthFailure.codeNotSent.message(for: .phone)) { _ in }
}
