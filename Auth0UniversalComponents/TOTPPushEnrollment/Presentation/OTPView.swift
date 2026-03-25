import SwiftUI
import Auth0

/// View for entering one-time passwords (OTP/MFA codes).
///
/// Displayed as a bottom sheet. Contains its own `#if os(iOS)` presentation
/// modifiers so every caller gets consistent detents, drag indicator and
/// corner radius without repetition.
struct OTPView: View {

    // MARK: - Theme
    @Environment(\.auth0Theme) private var theme
    // MARK: - Dismiss
    @Environment(\.dismiss) private var dismiss
    // MARK: - View Model
    @StateObject private var viewModel: OTPViewModel

    // MARK: - Properties
    @FocusState private var focusedField: Int?

    // MARK: - Init
    init(viewModel: OTPViewModel) {
        _viewModel = StateObject(wrappedValue: viewModel)
    }

    // MARK: - Body
    var body: some View {
        VStack(spacing: 0) {
            
            // Dismiss button
            HStack {
                Button {
                    dismiss()
                } label: {
                    Image("ic_dismiss", bundle: ResourceBundle.default)
                }
                Spacer()
            }
            .padding(.top, theme.spacing.md)
            .padding(.horizontal, theme.spacing.lg)

            if viewModel.showLoader {
                Spacer()
                Auth0Loader()
                Spacer()
            } else {
                VStack(alignment: .leading, spacing: theme.spacing.xxxl) {
                    if viewModel.isEmailOrSMS {
                        emailOrSmsHeaderView()
                    } else {
                        authenticatorHeaderView()
                    }

                    VStack(alignment: .leading, spacing: theme.spacing.xs) {
                        
                        Text("One-Time Passcode")
                            .auth0TextStyle(theme.typography.label)
                            .foregroundStyle(theme.colors.text.bold)
                            .padding(.bottom, theme.spacing.md)

                        otpTextFieldView()
                        
                        otpViewSubtitle()
                            .frame(maxWidth: .infinity, alignment: .center)
                    }
                }
                .padding(.top, theme.spacing.xl)
                .padding(.horizontal, theme.spacing.lg)
            }

            Spacer()

            continueButton()
                .padding(.horizontal, theme.spacing.lg)
                .padding(.bottom, theme.spacing.xl)
        }
        .onAppear {
            focusedField = 0
        }
        .frame(maxWidth: .infinity)
        .ignoresSafeArea()
        .background(theme.colors.background.layerBase)
        #if os(iOS)
        .presentationDetents([.fraction(0.65), .large])
        .presentationDragIndicator(.visible)
        .modifier(RoundedSheetModifier())
        #endif
    }
    
    // MARK: - Authenticator View
    @ViewBuilder
    private func authenticatorHeaderView() -> some View {
        VStack(alignment: .leading, spacing: theme.spacing.xs) {
            Text("Enter the 6-digit code")
                .auth0TextStyle(theme.typography.titleLarge)
                .foregroundStyle(theme.colors.text.bold)

            Text("From your authenticator app")
                .auth0TextStyle(theme.typography.body)
                .foregroundStyle(theme.colors.text.regular)
        }
    }
    
    @ViewBuilder
    private func emailOrSmsHeaderView() -> some View {
        VStack(alignment: .leading, spacing: theme.spacing.xs) {
            Text("Enter the 6 digit code")
                .multilineTextAlignment(.leading)
                .auth0TextStyle(theme.typography.titleLarge)
                .foregroundStyle(theme.colors.text.bold)

            Text(attributedStringEmailOrSmsDescription())
                .auth0TextStyle(theme.typography.body)
                .foregroundStyle(theme.colors.text.regular)
        }
    }

    // MARK: - OTP fields
    private func otpTextFieldView() -> some View {
        HStack(spacing: theme.spacing.xs) {
            ForEach(0..<6, id: \.self) { index in
                OTPTextField(
                    fullText: $viewModel.otpText,
                    index: index,
                    digitCount: 6,
                    setText: { setTextAtIndex($0, at: index) },
                    enterKeyPressed: { focusedField = nil },
                    emptyBackspaceKeyPressed: { emptyBackspaceKeyPressed() }
                )
                .frame(width: theme.sizes.size2xlDimen, height: theme.sizes.size3xlDimen,
                       alignment: .center)
                .background(
                    RoundedRectangle(cornerRadius: theme.radius.small, style: .continuous)
                        .stroke(theme.colors.border.regular, lineWidth: 2)
                )
                .tag(index)
                .focused($focusedField, equals: index)
            }
        }
    }

    // MARK: - Input helpers
    private func setTextAtIndex(_ string: String, at index: Int) {
        let old = viewModel.otpText
        let strBefore = old.prefix(length: index)
        let suffixLength = old.count - index - (string.isEmpty ? 1 : string.count)
        let strAfter = suffixLength <= 0 ? "" : old.suffix(length: suffixLength)
        let new = (strBefore + string + strAfter).prefix(length: 6)
        viewModel.otpText = new

        guard let focusedField else { return }
        if focusedField <= old.count - 1 {
            let newFocus = focusedField + (string.isEmpty ? -1 : string.count)
            self.focusedField = newFocus >= 6 ? nil : newFocus
            return
        }
        let newFocus = new.count
        self.focusedField = newFocus >= 6 ? nil : newFocus
    }

    private func emptyBackspaceKeyPressed() {
        guard let focusedField, focusedField > 0 else { return }
        self.focusedField = focusedField - 1
    }

    // MARK: - Attributted strings
    func resendCodeText() -> AttributedString {
        var attributed = AttributedString("Resend Code")
        if let range = attributed.range(of: "Resend Code") {
            attributed[range].foregroundColor = theme.colors.text.bold
            attributed[range].underlineStyle = .single
        }
        return attributed
    }
    
    func attributedStringEmailOrSmsDescription() -> AttributedString {
        var attributedString = AttributedString("We have sent you a verification code to \(viewModel.formattedEmailOrPhoneNumber)")
        if let range = attributedString.range(of: "\(viewModel.formattedEmailOrPhoneNumber)") {
            attributedString[range].foregroundColor = theme.colors.text.bold
            attributedString[range].font = theme.typography.title.font
        }
        return attributedString
    }
    
    // MARK: OTP Subtitle view
    @ViewBuilder
    private func otpViewSubtitle() -> some View {
        VStack(spacing: theme.spacing.md) {
            
            if let errorMessage = viewModel.errorMessage {
                Text(errorMessage)
                    .foregroundStyle(theme.colors.text.onError)
                    .auth0TextStyle(theme.typography.body)
                    .padding(EdgeInsets(top: theme.spacing.md, leading: 0,
                                        bottom: theme.spacing.md, trailing: 0))
            }
            
            if viewModel.isEmailOrSMS {
                Text(resendCodeText())
                    .auth0TextStyle(theme.typography.body)
                    .foregroundStyle(theme.colors.text.regular)
                    .onTapGesture {
                        Task { await viewModel.restartEnrollment() }
                    }
                    .padding(EdgeInsets(top: theme.spacing.md, leading: 0,
                                        bottom: theme.spacing.md, trailing: 0))
            }
        }
    }
    
    // MARK: - Continue button
    @ViewBuilder
    fileprivate func continueButton() -> some View {
        Button(action: {
            Task { await viewModel.confirmEnrollment() }
        }, label: {
            HStack {
                if viewModel.apiCallInProgress {
                    Auth0Loader(tintColor: theme.colors.text.onPrimary)
                } else {
                    Text("Continue")
                        .foregroundStyle(theme.colors.text.onPrimary)
                        .auth0TextStyle(theme.typography.label)
                }
            }.frame(maxWidth: .infinity)
        })
        .disabled(!viewModel.buttonEnabled || viewModel.showLoader)
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
    }
}
