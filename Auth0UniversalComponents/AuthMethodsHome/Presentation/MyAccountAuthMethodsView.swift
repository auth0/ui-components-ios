import SwiftUI
import Combine
import Auth0

/// Full-screen view for viewing and managing Auth0 MFA authentication methods.
///
/// Displays enrolled factors (Email OTP, SMS OTP, TOTP, Push, Passkeys, Recovery Codes),
/// lets users enroll in new ones, and navigates to per-factor management screens.
///
/// ## Standalone
///
/// Drop it anywhere — the view creates and owns its own `NavigationStack`:
///
/// ```swift
/// MyAccountAuthMethodsView()
/// ```
///
/// ## Embedded in a host `NavigationStack`
///
/// Two setup steps are required to avoid SwiftUI's nested-stack dismissal bug:
///
/// **Step 1** — inject the host path binding on your root `NavigationStack`:
/// ```swift
/// NavigationStack(path: $router.path) { ... }
///     .environment(\.hostNavigationPath, $router.path)
/// ```
///
/// **Step 2** — apply `.embeddedInNavigationStack()` at the push site:
/// ```swift
/// .navigationDestination(for: AppRoute.self) { route in
///     switch route {
///     case .loginSecurity:
///         MyAccountAuthMethodsView()
///             .embeddedInNavigationStack()
///     }
/// }
/// ```
///
/// - Precondition: Call `Auth0UniversalComponentsSDKInitializer.initialize(tokenProvider:)`
///   before this view appears.
public struct MyAccountAuthMethodsView: View {

    // MARK: - Environment

    @Environment(\.auth0Theme) private var theme
    @Environment(\.isEmbeddedInNavigationStack) private var isEmbedded
    @Environment(\.hostNavigationPath) private var hostPath
    @Environment(\.dismiss) private var dismiss

    // MARK: - State

    /// Drives push navigation for SDK-internal routes.
    ///
    /// In standalone mode it owns an internal `NavigationPath`.
    /// In embedded mode `useExternalPath(_:)` redirects all navigation
    /// operations to the host stack's path.
    @StateObject private var router = Router<Route>()

    /// Loads and exposes the list of authentication methods and enrollment state.
    @StateObject private var viewModel: MyAccountAuthMethodsViewModel

    /// When `true`, the passkey enrollment banner is hidden.
    @State var collapsePasskeyBanner: Bool = false

    // MARK: - Email/Phone sheet state

    @State private var emailPhoneSheetType: AuthMethodType?
    @State private var showEmailPhoneSheet = false
    /// Holds the OTP config received from EmailPhoneEnrollmentView, pending the dismiss animation.
    @State private var pendingOTPConfig: OTPSheetConfig?
    @State private var otpViewModel: OTPViewModel?
    @State private var showOTPSheet = false
    @State private var pendingNavigationRoute: Route?

    // MARK: - Init

    /// Creates the view. Dependencies are resolved from the environment at render time.
    public init() {
        _viewModel = StateObject(wrappedValue: MyAccountAuthMethodsViewModel())
    }

    // MARK: - Body

    public var body: some View {
        // Capture the host dismiss action before any inner NavigationStack can
        // override the dismiss environment for its own children.
        let hostDismiss = dismiss

        if isEmbedded {
            // Embedded: no inner NavigationStack — destinations attach to the
            // host stack. The SDK router is redirected to the host path on appear.
            sdkRootContent
                .navigationTitle(Text("Login & Security"))
                #if !os(macOS)
                .navigationBarTitleDisplayMode(.inline)
                #endif
                #if !os(macOS)
                .navigationBarBackButtonHidden(true)
                #endif
                .toolbar {
                    ToolbarItem(placement: .platformLeading) {
                        Button {
                            hostDismiss()
                        } label: {
                            Image(systemName: "chevron.left")
                                .foregroundStyle(theme.colors.text.bold)
                        }
                    }
                }
                .navigationDestination(for: Route.self) { route in
                    ViewFactory.view(for: route, delegate: viewModel)
                        .environmentObject(router)
                }
                .environmentObject(router)
                .onAppear {
                    router.useExternalPath(hostPath)
                }
        } else {
            // Standalone: the SDK owns the full NavigationStack.
            NavigationStack(path: $router.path) {
                sdkRootContent
                    .navigationTitle(Text("Login & Security"))
                    #if !os(macOS)
                    .navigationBarTitleDisplayMode(.inline)
                    #endif
                    .navigationDestination(for: Route.self) { route in
                        ViewFactory.view(for: route, delegate: viewModel)
                            .environmentObject(router)
                    }
            }
            .environmentObject(router)
        }
    }

    // MARK: - SDK Root Content

    @ViewBuilder
    private var sdkRootContent: some View {
        ZStack {
            if let errorViewModel = viewModel.errorViewModel {
                ErrorScreen(viewModel: errorViewModel)
                    .padding()
            } else {
                ScrollView(showsIndicators: false) {
                    LazyVStack(alignment: .leading, spacing: theme.spacing.xs) {
                        ForEach(viewModel.viewComponents, id: \.self) { component in
                            authMethodView(component)
                        }
                    }.padding(.all, theme.spacing.md)
                }
                .disabled(viewModel.showLoader)
            }

            if viewModel.showLoader {
                loadingOverlay
            }
        }
        .onAppear {
            Task {
                await viewModel.loadMyAccountAuthViewComponentData()
            }
        }
        // Email/Phone enrollment sheet — presented instead of pushing the route
        .sheet(isPresented: $showEmailPhoneSheet, onDismiss: {
            guard let config = pendingOTPConfig else { return }
            pendingOTPConfig = nil
            let vm = OTPViewModel(
                totpEnrollmentChallenge: config.totpEnrollmentChallenge,
                emailEnrollmentChallenge: config.emailEnrollmentChallenge,
                phoneEnrollmentChallenge: config.phoneEnrollmentChallenge,
                type: config.type,
                emailOrPhoneNumber: config.emailOrPhoneNumber,
                delegate: viewModel,
                onSuccess: { type in
                    pendingNavigationRoute = .filteredAuthListScreen(type: type, authMethods: [])
                    showOTPSheet = false
                }
            )
            otpViewModel = vm
            showOTPSheet = true
        }) {
            if let type = emailPhoneSheetType {
                EmailPhoneEnrollmentView(
                    viewModel: EmailPhoneEnrollmentViewModel(type: type),
                    onOTPReady: { config in
                        pendingOTPConfig = config
                        showEmailPhoneSheet = false
                    }
                )
            }
        }
        // OTP sheet — presented after email/phone sheet finishes dismissing (via onDismiss above).
        // Attached to a separate view node to avoid the multiple-.sheet-on-same-view issue.
        .background(
            Color.clear
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
    }

    // MARK: - Loading Overlay

    private var loadingOverlay: some View {
        Color.black.opacity(0.25)
            .ignoresSafeArea()
            .overlay {
                VStack(spacing: theme.spacing.md) {
                    ProgressView()
                        .progressViewStyle(CircularProgressViewStyle())
                        .tint(theme.colors.background.primary)
                        .scaleEffect(1.4)

                    Text("Loading…")
                        .auth0TextStyle(theme.typography.label)
                        .foregroundStyle(theme.colors.text.bold)
                }
                .padding(.horizontal, 36)
                .padding(.vertical, 28)
                .background(theme.colors.background.layerTop)
                .clipShape(RoundedRectangle(cornerRadius: 20))
                .shadow(color: Color.black.opacity(0.18), radius: 24, x: 0, y: 8)
            }
    }

    // MARK: - Sheet helpers

    private func presentEmailPhoneSheet(type: AuthMethodType) {
        emailPhoneSheetType = type
        showEmailPhoneSheet = true
    }

    // MARK: - Component Builder

    /// Returns the view for a single `MyAccountAuthViewComponentData` item.
    @ViewBuilder
    private func authMethodView(_ component: MyAccountAuthViewComponentData) -> some View {
        switch component {
        case .createPasskey(let model):
            if #available(iOS 16.6, macOS 13.5, visionOS 1.0, *) {
                if let viewModel = model as? PasskeysEnrollmentViewModel,
                    collapsePasskeyBanner == false {
                    EnrollPasskeyView(collapsePasskeyBanner: $collapsePasskeyBanner,
                                      viewModel: viewModel)
                        .padding(.bottom, theme.spacing.xl)
                }
            }
        case .signinMethods(let viewModel):
            MyAccountAuthMethodView(viewModel: viewModel,
                                    onPresentEmailPhoneSheet: presentEmailPhoneSheet)
                .padding(.bottom, theme.spacing.xxl)
        case .title(let text):
            Text(text)
                .foregroundStyle(theme.colors.text.bold)
                .auth0TextStyle(theme.typography.titleLarge)
        case .subtitle(let text):
            Text(text)
                .foregroundStyle(theme.colors.text.regular)
                .auth0TextStyle(theme.typography.helper)
                .padding(.bottom, theme.spacing.md)
        case .additionalVerificationMethods(let viewModel):
            MyAccountAuthMethodView(viewModel: viewModel,
                                    onPresentEmailPhoneSheet: presentEmailPhoneSheet)
        case .emptyFactors:
            EmptyFactorsView()
        }
    }
}
