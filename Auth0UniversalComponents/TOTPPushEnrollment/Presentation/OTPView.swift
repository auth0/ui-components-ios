import SwiftUI
import Auth0

/// View for entering one-time passwords (OTP/MFA codes).
///
/// Displays a form for users to enter 6-digit codes from various sources:
/// - Email or SMS messages
/// - Authenticator apps (TOTP)
/// - Push notification confirmations
///
/// The view auto-advances between fields and validates codes on entry.
struct OTPView: View {

    @Environment(\.auth0Theme) private var theme
    /// View model managing OTP verification state and logic
    @StateObject private var viewModel: OTPViewModel
    /// Tracks which OTP field currently has focus
    @FocusState private var focusedField: Int?

    /// Initializes the OTP verification view.
    ///
    /// - Parameter viewModel: The view model managing OTP verification state and logic
    init(viewModel: OTPViewModel) {
        _viewModel = StateObject(wrappedValue: viewModel)
    }

    var body: some View {
        VStack {
            if viewModel.showLoader {
                Auth0Loader()
            } else {
                VStack(alignment: .leading) {
                    if viewModel.isEmailOrSMS == false {
                        Text("Enter the 6-digit code")
                            .auth0TextStyle(theme.typography.titleLarge)
                            .foregroundStyle(theme.colors.text.bold)
                            .padding(.bottom, theme.spacing.xs)

                        Text("From your authenticator app")
                            .auth0TextStyle(theme.typography.body)
                            .foregroundStyle(theme.colors.text.regular)
                            .padding(.bottom, 76)
                    } else {
                        Text("Enter the 6 digit code we sent to \(viewModel.formattedEmailOrPhoneNumber)")
                            .multilineTextAlignment(.leading)
                            .auth0TextStyle(theme.typography.titleLarge)
                            .foregroundStyle(theme.colors.text.bold)
                            .padding(.bottom, 30)
                    }

                    Text("One-Time Passcode")
                        .auth0TextStyle(theme.typography.label)
                        .foregroundStyle(theme.colors.text.bold)
                        .padding(.bottom, theme.spacing.md)

                    otpTextFieldView()

                    if let errorMessage = viewModel.errorMessage {
                        Text(errorMessage)
                            .foregroundStyle(theme.colors.text.onError)
                            .auth0TextStyle(theme.typography.body)
                            .padding(EdgeInsets(top: 16, leading: 0, bottom: 100, trailing: 0))
                    } else {
                        if viewModel.isEmailOrSMS {
                            Text(attributedString())
                                .auth0TextStyle(theme.typography.body)
                                .foregroundStyle(theme.colors.text.regular)
                                .onTapGesture {
                                    Task {
                                        await viewModel.restartEnrollment()
                                    }
                                }.padding(EdgeInsets(top: 30, leading: 0, bottom: 100, trailing: 0))
                        } else {
                            Spacer()
                        }
                    }

                    Button(action: {
                        Task {
                            await viewModel.confirmEnrollment()
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
                    .disabled(!viewModel.buttonEnabled)
                    .frame(height: theme.sizes.buttonHeight)
                    .background(
                        theme.colors.background.primary.opacity(viewModel.buttonEnabled ? 1.0 : 0.5)
                    )
                    .cornerRadius(theme.radius.button)
                    .overlay(
                        RoundedRectangle(cornerRadius: theme.radius.button)
                            .stroke(
                                theme.colors.background.primary.opacity(viewModel.buttonEnabled ? 1.0 : 0.5),
                                lineWidth: 2
                            )
                    )
                    Spacer()
                }.padding(EdgeInsets(top: 39, leading: 16, bottom: 40, trailing: 16))
            }
        }
        .ignoresSafeArea(.keyboard)
        .navigationTitle(viewModel.navigationTitle)
        .onAppear {
            focusedField = 0
        }
    }

    private func otpTextFieldView() -> some View {
        HStack(spacing: theme.spacing.xs) {
            ForEach(0..<6, id: \.self, content: { index in
                OTPTextField(
                    fullText: $viewModel.otpText,
                    index: index,
                    digitCount: 6,
                    setText: { string in
                        self.setTextAtIndex(string, at: index)
                    },
                    enterKeyPressed: {
                        self.enterKeyPressed()
                    },
                    emptyBackspaceKeyPressed: {
                        self.emptyBackspaceKeyPressed()
                    }
                )
                .frame(width: theme.sizes.size2xlDimen, height: theme.sizes.size3xlDimen, alignment: .center)
                .background(
                    RoundedRectangle(cornerRadius: theme.radius.small, style: .continuous)
                        .stroke(Color.gray, lineWidth: 2)
                )
                .tag(index)
                .focused($focusedField, equals: index)
            })
        }
    }

    private func setTextAtIndex(_ string: String, at index: Int) {
        let old = viewModel.otpText

        let strBefore = old.prefix(length: index)
        let suffixLength = old.count - index - (string.isEmpty ? 1 : string.count)

        let strAfter = suffixLength <= 0 ? "" : old.suffix(length: suffixLength)

        let new = (strBefore + string + strAfter).prefix(length: 6)

        viewModel.otpText = new

        guard let focusedField = self.focusedField else {
            return
        }

        if focusedField <= old.count - 1 {
            let newFocus = focusedField + (string.isEmpty ? -1 : string.count)

            self.focusedField = newFocus >= 6 ? nil : newFocus
            return
        }

        let newFocus = new.count
        if newFocus >= 6 {
            self.focusedField = nil
            return
        }

        self.focusedField = newFocus
    }

    private func enterKeyPressed() {
        self.focusedField = nil
    }

    private func emptyBackspaceKeyPressed() {
        guard let focusedField = self.focusedField, focusedField > 0 else {
            return
        }
        self.focusedField = focusedField - 1
    }

    func attributedString() -> AttributedString {
        var attributed = AttributedString("Didn't get a code? Resend it.")
        if let range = attributed.range(of: "Resend it.") {
            attributed[range].foregroundColor = theme.colors.text.bold
            attributed[range].underlineStyle = .single
        }
        return attributed
    }
}
