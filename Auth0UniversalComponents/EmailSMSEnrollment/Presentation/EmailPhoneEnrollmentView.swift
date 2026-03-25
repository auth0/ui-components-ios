import SwiftUI

/// View for entering email or phone number for enrollment.
///
/// Supports two presentation modes:
/// - **Sheet mode** (when `onOTPReady` is provided): shows an X dismiss button,
///   self-contained presentation detents, and delegates OTP progression to the caller.
/// - **Nav-push mode** (when `onOTPReady` is nil): retains navigation title/toolbar
///   and presents the OTP sheet internally (legacy path via ViewFactory).
struct EmailPhoneEnrollmentView: View {

    @Environment(\.auth0Theme) private var theme
    @Environment(\.dismiss) private var dismiss
    @EnvironmentObject private var router: Router<Route>

    @StateObject private var viewModel: EmailPhoneEnrollmentViewModel
    @FocusState private var textFieldFocused: Bool

    // Legacy nav-push state (only used when onOTPReady == nil)
    @State private var otpViewModel: OTPViewModel?
    @State private var showOTPSheet = false
    @State private var pendingNavigationRoute: Route?

    /// Closure called when the enrollment API succeeds and OTP entry is ready.
    /// When set the view operates in sheet mode; when nil it falls back to push navigation.
    var onOTPReady: ((OTPSheetConfig) -> Void)?

    init(viewModel: EmailPhoneEnrollmentViewModel,
         onOTPReady: ((OTPSheetConfig) -> Void)? = nil) {
        _viewModel = StateObject(wrappedValue: viewModel)
        self.onOTPReady = onOTPReady
    }

    private var isSheetMode: Bool { onOTPReady != nil }

    // MARK: - Main body
    var body: some View {
        VStack(alignment: .leading, spacing: 0) {

            if isSheetMode {
                HStack {
                    Button {
                        dismiss()
                    } label: {
                        Image("ic_dismiss", bundle: ResourceBundle.default)
                            .foregroundStyle(theme.colors.text.regular)
                            .background(theme.colors.background.layerMedium)
                            .clipShape(Circle())
                    }
                    Spacer()
                }
                .padding(.top, theme.spacing.md)
                .padding(.bottom, theme.spacing.md)
                .padding(.horizontal, theme.spacing.lg)
            }

            Group {
                Text(viewModel.title)
                    .auth0TextStyle(theme.typography.titleLarge)
                    .foregroundStyle(theme.colors.text.bold)
                    .padding(.bottom, theme.spacing.xs)

                Text("We will text you a verification code.")
                    .auth0TextStyle(theme.typography.body)
                    .foregroundStyle(theme.colors.text.regular)
                    .padding(.bottom, theme.spacing.lg)

                Text(viewModel.isPhoneAuthMethod ? "Phone number" : "Email")
                    .auth0TextStyle(theme.typography.label)
                    .foregroundStyle(theme.colors.text.bold)
                    .padding(.bottom, theme.spacing.xs)

                if viewModel.isPhoneAuthMethod {
                    phoneInputField()
                } else {
                    emailInputField()
                }
            }
            .padding(.horizontal, theme.spacing.lg)

            Spacer()
            
            continueButton()
                .padding(.horizontal, theme.spacing.lg)
                .padding(.bottom, theme.spacing.xl)
        }
        .frame(maxWidth: .infinity)
        .ignoresSafeArea(.keyboard)
        .navigationTitle(isSheetMode ? Text("") : Text(viewModel.title))
        // Country picker — the only sheet inside this view (no conflict)
        .sheet(isPresented: $viewModel.isPickerVisible) {
            CountryPickerView(selectedCountry: $viewModel.selectedCountry,
                              isPickerVisible: $viewModel.isPickerVisible)
        }
        // Legacy OTP sheet — only active in nav-push mode (onOTPReady == nil)
        .background(
         theme.colors.background.layerBase
            .ignoresSafeArea(edges: .bottom)
            .sheet(isPresented: $showOTPSheet, onDismiss: {
                if let route = pendingNavigationRoute {
                    router.navigate(to: route)
                    pendingNavigationRoute = nil
                    otpViewModel = nil
                }
            }) {
                if let vm = otpViewModel {
                    OTPView(viewModel: vm)
                }
            }
        )
        .onAppear { textFieldFocused = true }
        .onDisappear { textFieldFocused = false }
        .onChange(of: viewModel.otpSheetConfig) { _ in
            guard let config = viewModel.otpSheetConfig else { return }
            if let onOTPReady {
                // Sheet mode: notify parent then dismiss; parent manages OTP sheet
                onOTPReady(config)
                dismiss()
            } else {
                // Nav-push mode: present OTP sheet internally
                let vm = OTPViewModel(
                    totpEnrollmentChallenge: config.totpEnrollmentChallenge,
                    emailEnrollmentChallenge: config.emailEnrollmentChallenge,
                    phoneEnrollmentChallenge: config.phoneEnrollmentChallenge,
                    type: config.type,
                    emailOrPhoneNumber: config.emailOrPhoneNumber,
                    delegate: nil,
                    onSuccess: { type in
                        pendingNavigationRoute = .filteredAuthListScreen(type: type, authMethods: [])
                        showOTPSheet = false
                    }
                )
                otpViewModel = vm
                showOTPSheet = true
            }
        }
        #if os(iOS)
        .presentationDetents([.fraction(0.65), .large])
        .presentationDragIndicator(.visible)
        .modifier(RoundedSheetModifier())
        #endif
    }

    // MARK: - Sub-views

    @ViewBuilder
    private func phoneInputField() -> some View {
        HStack(spacing: theme.spacing.xs) {
            Button(action: { viewModel.isPickerVisible.toggle() }) {
                HStack {
                    Text(viewModel.selectedCountry?.flag ?? "").frame(height: 20)
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
                .padding(EdgeInsets(top: 16, leading: 0, bottom: 0, trailing: 0))
        }
    }

    @ViewBuilder
    private func emailInputField() -> some View {
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
                .padding(EdgeInsets(top: 16, leading: 0, bottom: 0, trailing: 0))
        }
    }

    @ViewBuilder
    private func continueButton() -> some View {
        Button(action: {
            Task { await viewModel.startEnrollment() }
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
        .padding(.top, theme.spacing.xl)
    }
}
