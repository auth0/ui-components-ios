import SwiftUI

/// The "Phone number" label, a country code button, the number field and the error under it. The country picker opens
/// as a sheet. Holds no rules: whoever hosts it decides what's wrong.
struct LoginPhoneField: View {
    @Binding var country: Country?
    @Binding var number: String
    let error: String?
    /// Turned off while a request is on its way, so the country can't change under it.
    let isEnabled: Bool
    let isFocused: FocusState<Bool>.Binding
    let onSubmit: () -> Void

    @Environment(\.auth0Theme) private var theme
    @State private var isPickerVisible = false

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            LoginFieldLabel("Phone number")
            LoginInputField(isInvalid: error != nil) {
                HStack(spacing: theme.spacing.md) {
                    countryButton
                    TextField("", text: $number)
                        .phoneInput()
                        .focused(isFocused)
                        .onSubmit(onSubmit)
                        .accessibilityLabel("Phone number")
                }
            }

            if let error {
                LoginInlineError(error)
                    .padding(.top, theme.spacing.xs)
            }
        }
        .sheet(isPresented: $isPickerVisible) {
            CountryPickerView(selectedCountry: $country, isPickerVisible: $isPickerVisible)
        }
    }

    private var countryButton: some View {
        Button { isPickerVisible = true } label: {
            HStack(spacing: theme.spacing.xs) {
                // The emoji flag stands in until the design's flag images are added.
                Text(country.map { "\($0.flag) \($0.code)" } ?? "+")
                Image(systemName: "chevron.down")
                    .imageScale(.small)
                    .accessibilityHidden(true)
            }
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .disabled(!isEnabled)
        .accessibilityLabel("Country code")
        .accessibilityValue(country.map { "\($0.name), \($0.code)" } ?? "None selected")
        .accessibilityHint("Opens the list of countries")
    }
}
