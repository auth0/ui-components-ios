import SwiftUI
import Combine
import Auth0

/// The main view for managing authentication methods in Auth0 My Account.
///
/// This view provides a complete UI for users to:
/// - View their enrolled MFA methods (Email, SMS, TOTP, Push, Passkeys, Recovery codes)
/// - Enroll in new authentication methods
/// - Manage existing authenticators
///
/// The view automatically loads the user's authentication methods on appearance and refreshes
/// when returning from enrollment flows. It handles loading states, errors, and navigation
/// to specific enrollment screens.
///
/// Dependencies: Auth0UIComponentsSDKInitializer must be configured before using this view.
///
/// Example:
/// ```swift
/// // Make sure to initialize the SDK first
/// struct ContentView: View {
///     var body: some View {
///         NavigationStack {
///             MyAccountAuthMethodsView()
///                 .navigationTitle("My Account")
///         }
///     }
/// }
///
/// // In your App initialization
/// @main
/// struct MyApp: App {
///     init() {
///         let tokenProvider = MyTokenProvider()
///         Auth0UIComponentsSDKInitializer.initialize(
///             domain: "example.auth0.com",
///             clientId: "YOUR_CLIENT_ID",
///             audience: "https://example.auth0.com/me/",
///             tokenProvider: tokenProvider
///         )
///     }
///
///     var body: some Scene {
///         WindowGroup {
///             ContentView()
///         }
///     }
/// }
/// ```
public struct MyAccountAuthMethodsView: View {
    /// Shared navigation store for managing route state
    @StateObject private var navigationStore = NavigationStore.shared
    /// The main view model managing data and business logic
    @StateObject private var viewModel: MyAccountAuthMethodsViewModel
    /// Tracks previous navigation stack depth to detect returns to root
    @State private var previousPathCount = 0
    /// Controls visibility of the passkey enrollment banner
    @State var collapsePasskeyBanner: Bool = false

    /// Initializes the My Account Auth Methods view.
    public init() {
        _viewModel = StateObject(wrappedValue: MyAccountAuthMethodsViewModel())
    }

    // MARK: - Main body
    public var body: some View {
        NavigationStack(path: $navigationStore.path) {
            ZStack {
                if viewModel.showLoader {
                    Auth0Loader()
                }
                else if let errorViewModel = viewModel.errorViewModel {
                    ErrorScreen(viewModel: errorViewModel)
                        .padding()
                }
                else {
                    ScrollView(showsIndicators: false) {
                        LazyVStack(alignment: .leading) {
                            ForEach(viewModel.viewComponents, id: \.self) { component in
                                authMethodView(component)
                            }
                        }.padding(.all, 16)
                    }
                }
            }
            .navigationTitle(Text("Login & Security"))
            #if !os(macOS)
                .navigationBarTitleDisplayMode(.inline)
            #endif
                .navigationDestination(for: Route.self) { route in
                    handleRoute(route: route, delegate: viewModel)
                }
        }.onReceive(navigationStore.$path) { path in
            if path.count < previousPathCount && path.isEmpty {
                Task {
                    await viewModel.loadMyAccountAuthViewComponentData()
                }
            }
            previousPathCount = path.count
        }
        .onAppear {
            Task {
                await viewModel.loadMyAccountAuthViewComponentData()
            }
        }
    }

    /// Builds the appropriate view for each component in the auth methods list.
    ///
    /// - Parameter component: The component data to render
    /// - Returns: A SwiftUI View for the component
    @ViewBuilder
    private func authMethodView(_ component: MyAccountAuthViewComponentData) -> some View {
        switch component {
        case .createPasskey(let model):
            if #available(iOS 16.6, macOS 13.5, visionOS 1.0, *) {
                if let viewModel = model as? PasskeysEnrollmentViewModel,
                    collapsePasskeyBanner == false {
                    EnrollPasskeyView(collapsePasskeyBanner: $collapsePasskeyBanner,
                                      viewModel: viewModel)
                        .padding(.bottom, 24)
                }
            }
        case .signinMethods(let viewModel):
            MyAccountAuthMethodView(viewModel: viewModel)
                .padding(.bottom, 48)
        case .title(let text):
            Text(text)
                .textStyle(.title)
        case .subtitle(let text):
            Text(text)
                .textStyle(.bodySmall)
        case .additionalVerificationMethods(let viewModel):
            MyAccountAuthMethodView(viewModel: viewModel)
        case .emptyFactors:
            EmptyFactorsView()
        }
    }

    /// Handles navigation to enrollment or management screens based on the route.
    ///
    /// - Parameters:
    ///   - route: The navigation route to handle
    ///   - delegate: The refresh delegate for updating data after operations
    /// - Returns: A SwiftUI View for the destination
    @ViewBuilder
    private func handleRoute(route: Route, delegate: RefreshAuthDataProtocol?) -> some View {
        switch route {
        case let .totpPushQRScreen(type):
            TOTPPushQRCodeView(viewModel: TOTPPushQRCodeViewModel(type: type,
                                                                  delegate: delegate))
        case let .otpScreen(type,
                            emailOrPhoneNumber,
                            totpEnrollmentChallege,
                            phoneEnrollmentChallenge,
                            emailEnrollmentChallenge):
            OTPView(viewModel: OTPViewModel(totpEnrollmentChallenge: totpEnrollmentChallege,
                                            emailEnrollmentChallenge: emailEnrollmentChallenge,
                                            phoneEnrollmentChallenge: phoneEnrollmentChallenge,
                                            type: type,
                                            emailOrPhoneNumber: emailOrPhoneNumber,
                                            delegate: delegate))
        case let .filteredAuthListScreen(type, authMethods):
            SavedAuthenticatorsView(viewModel: SavedAuthenticatorsViewModel(type: type,
                                                                            authenticationMethods: authMethods,
                                                                            delegate: delegate))
        case let .emailPhoneEnrollmentScreen(type):
            EmailPhoneEnrollmentView(viewModel: EmailPhoneEnrollmentViewModel(type: type))
        case .recoveryCodeScreen:
            RecoveryCodeEnrollmentView(viewModel: RecoveryCodeEnrollmentViewModel(delegate: delegate))
        case .enrollPasskeyScreen:
            if #available(iOS 16.6, macOS 13.5, visionOS 1.0, *) {
                PasskeysEnrollmentView(viewModel: PasskeysEnrollmentViewModel(delegate: delegate))
            }
        }
    }
}
