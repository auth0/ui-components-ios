import SwiftUI

/// View for entering email or phone number for enrollment.
///
/// Allows users to input an email address or phone number to enroll as an
/// authentication method. For phone numbers, includes a country code picker.
struct EmailPhoneEnrollmentView: View {

    @Environment(\.auth0Theme) private var theme
    /// View model managing email/phone enrollment state and validation
    @StateObject private var viewModel: EmailPhoneEnrollmentViewModel
    /// Manages focus state of the text input field
    @FocusState private var textFieldFocused: Bool

    /// Initializes the email/phone enrollment view.
    ///
    /// - Parameter viewModel: The view model managing email/phone enrollment state
    init(viewModel: EmailPhoneEnrollmentViewModel) {
        _viewModel = StateObject(wrappedValue: viewModel)
    }

    var body: some View {
        VStack(alignment: .leading) {
            Text(viewModel.title)
                .auth0TextStyle(theme.typography.titleLarge)
                .foregroundStyle(theme.colors.text.bold)
                .padding(.bottom, theme.spacing.xs)

            Text("We will text you a verification code.")
                .auth0TextStyle(theme.typography.body)
                .foregroundStyle(theme.colors.text.regular)
                .padding(.bottom, 25)

            Text(viewModel.isPhoneAuthMethod ? "Phone number" : "Email")
                .auth0TextStyle(theme.typography.label)
                .foregroundStyle(theme.colors.text.bold)
                .padding(.bottom, theme.spacing.xs)

            if viewModel.isPhoneAuthMethod {
                HStack(spacing: theme.spacing.xs) {
                    Button(action: {
                        viewModel.isPickerVisible.toggle()
                    }) {
                        HStack {
                            Text(viewModel.selectedCountry?.flag ?? "")
                                .frame(height: 20)

                            Text(viewModel.selectedCountry?.code ?? "")
                                .foregroundStyle(theme.colors.text.bold)
                                .auth0TextStyle(theme.typography.titleLarge)
                        }.padding(5)
                    }

                    Image("chevrondown", bundle: ResourceBundle.default)
                        .frame(width: 10, height: 5.5)
                    TextField("Phone Number", text: $viewModel.phoneNumber)
                    #if !os(macOS)
                        .keyboardType(.numberPad)
                    #endif
                        .focused($textFieldFocused)
                }
                .padding()
                .frame(height: theme.sizes.inputHeight)
                .clipShape(RoundedRectangle(cornerRadius: theme.radius.inputField))
                .overlay {
                    RoundedRectangle(cornerRadius: theme.radius.inputField)
                        .stroke(theme.colors.border.regular, lineWidth: 1)
                }

                if let errorMessage = viewModel.errorMessage {
                    Text(errorMessage)
                        .foregroundStyle(theme.colors.text.onError)
                        .auth0TextStyle(theme.typography.body)
                        .padding(EdgeInsets(top: 16, leading: 0, bottom: 100, trailing: 0))
                } else {
                    EmptyView()
                    .padding(.bottom, 100)
                }
            } else {
                TextField("Email", text: $viewModel.email)
                    .focused($textFieldFocused)
                    .padding()
                    .frame(height: theme.sizes.inputHeight)
                    .clipShape(RoundedRectangle(cornerRadius: theme.radius.inputField))
                    .overlay {
                        RoundedRectangle(cornerRadius: theme.radius.inputField)
                            .stroke(theme.colors.border.regular, lineWidth: 1)
                    }

                if let errorMessage = viewModel.errorMessage {
                    Text(errorMessage)
                        .foregroundStyle(theme.colors.text.onError)
                        .auth0TextStyle(theme.typography.body)
                        .padding(EdgeInsets(top: 16, leading: 0, bottom: 100, trailing: 0))
                } else {
                    EmptyView()
                        .padding(.bottom, 100)
                }
            }

            Button(action: {
                Task {
                    await viewModel.startEnrollment()
                }
            }, label: {
                HStack {
                    Spacer()
                    if viewModel.apiCallInProgress {
                        Auth0Loader(tintColor: theme.colors.text.onPrimary)
                    } else {
                        Text("Continue")
                            .foregroundStyle(theme.colors.text.onPrimary)
                            .auth0TextStyle(theme.typography.label)
                    }
                    Spacer()
                }.frame(maxWidth: .infinity)
            })
            .disabled(!viewModel.isButtonEnabled)
            .frame(height: theme.sizes.buttonHeight)
            .background(
                theme.colors.background.primary.opacity(viewModel.isButtonEnabled ? 1.0 : 0.5)
            )
            .cornerRadius(theme.radius.button)
            .overlay(
                RoundedRectangle(cornerRadius: theme.radius.button)
                    .stroke(
                        theme.colors.background.primary.opacity(viewModel.isButtonEnabled ? 1.0 : 0.5),
                        lineWidth: 2
                    )
            )
            Spacer()
        }
        .padding()
        .ignoresSafeArea(.keyboard)
        .navigationTitle(Text(viewModel.navigationTitle))
        .toolbar {
            #if !os(visionOS)
            ToolbarItemGroup(placement: .keyboard) {
                Spacer()
                Button("Done") {
                    textFieldFocused = false
                }
            }
            #endif
        }
        .sheet(isPresented: $viewModel.isPickerVisible) {
            CountryPickerView(selectedCountry: $viewModel.selectedCountry,
                              isPickerVisible: $viewModel.isPickerVisible)
        }
        .onAppear {
            textFieldFocused = true
        }
        .onDisappear {
            textFieldFocused = false
        }
    }
}
