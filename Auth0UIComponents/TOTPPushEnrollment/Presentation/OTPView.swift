import SwiftUI

/// View for entering one-time passwords (OTP/MFA codes).
///
/// Displays a form for users to enter 6-digit codes from various sources:
/// - Email or SMS messages
/// - Authenticator apps (TOTP)
/// - Push notification confirmations
///
/// The view auto-advances between fields and validates codes on entry.
struct OTPView: View {
    /// View model managing OTP verification state and logic
    @ObservedObject var viewModel: OTPViewModel
    /// Tracks which OTP field currently has focus
    @FocusState private var focusedField: Int?

    var body: some View {
        VStack {
            if viewModel.showLoader {
                Auth0Loader()
            } else {
                VStack(alignment: .leading) {
                    if viewModel.isEmailOrSMS == false {
                        Text("Enter the 6-digit code")
                            .font(Font.system(size: 20, weight: .semibold))
                            .foregroundStyle(Color("000000", bundle: ResourceBundle.default))
                            .padding(.bottom, 8)
                        
                        Text("From your authenticator app")
                            .font(Font.system(size: 16))
                            .foregroundStyle(Color("606060", bundle: ResourceBundle.default))
                            .padding(.bottom, 76)
                    } else {
                        Text("Enter the 6 digit code we sent to \(viewModel.formattedEmailOrPhoneNumber)")
                            .multilineTextAlignment(.leading)
                            .font(Font.system(size: 20, weight: .semibold))
                            .foregroundStyle(Color("000000", bundle: ResourceBundle.default))
                            .padding(.bottom, 30)
                    }
                    
                    Text("One-Time Passcode")
                        .font(Font.system(size: 16, weight: .medium))
                        .foregroundStyle(Color("1F1F1F", bundle: ResourceBundle.default))
                        .padding(.bottom, 16)
                    
                    otpTextFieldView()
                    if let errorMessage = viewModel.errorMessage {
                        Text(errorMessage)
                            .foregroundStyle(Color("B82819", bundle: ResourceBundle.default))
                            .font(.system(size: 16))
                            .padding(EdgeInsets(top: 16, leading: 0, bottom: 100, trailing: 0))
                    } else {
                        if viewModel.isEmailOrSMS {
                            Text(attributedString())
                                .font(.system(size: 16))
                                .foregroundStyle(Color("606060", bundle: ResourceBundle.default))
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
                                Auth0Loader(tintColor: Color("FFFFFF", bundle: ResourceBundle.default))
                            } else {
                                Text("Continue")
                                    .foregroundStyle(Color("FFFFFF", bundle: ResourceBundle.default))
                                    .font(.system(size: 16, weight: .medium))
                            }
                            Spacer()
                        }.frame(maxWidth: .infinity)
                    })
                    .disabled(!viewModel.buttonEnabled)
                    .frame(height: 48)
                    .background(
                        Color("262420", bundle: ResourceBundle.default).opacity(viewModel.buttonEnabled ? 1.0 : 0.5)
                    )
                    .cornerRadius(16)
                    .overlay(
                        RoundedRectangle(cornerRadius: 16)
                            .stroke(
                                Color("262420", bundle: ResourceBundle.default).opacity(viewModel.buttonEnabled ? 1.0 : 0.5),
                                lineWidth: 2
                            )
                    )
                    Spacer()
                }.padding(EdgeInsets(top: 39, leading: 16, bottom: 40, trailing: 16))
            }
        }.ignoresSafeArea(.keyboard)
            .navigationTitle(viewModel.navigationTitle)
            .onAppear {
                focusedField = 0
            }
    }

    private func otpTextFieldView() -> some View {
        HStack(spacing: 8) {
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
                .frame(width: 48, height: 56, alignment: .center)
                .background(
                    RoundedRectangle(cornerRadius: 8, style: .continuous)
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
        var attributed = AttributedString("Didn’t get a code? Resend it.")
        if let range = attributed.range(of: "Resend it.") {
            attributed[range].foregroundColor = Color("000000", bundle: ResourceBundle.default)
            attributed[range].underlineStyle = .single
        }
        return attributed
    }
}
