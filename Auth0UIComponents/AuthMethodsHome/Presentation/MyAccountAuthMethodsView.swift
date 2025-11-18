import SwiftUI

/// The main view for managing authentication methods and MFA enrollment.
///
/// MyAccountAuthMethodsView provides a user interface for:
/// - Viewing all enrolled authentication methods (TOTP, Push, Email, SMS, Recovery Codes)
/// - Enrolling in new authentication methods
/// - Deleting existing authentication methods
/// - Managing recovery codes
///
/// This view handles navigation to various enrollment and management screens based on user actions.
/// It displays loading states, error states, and the list of available authentication methods.
///
/// Example usage:
/// ```swift
/// NavigationStack {
///     MyAccountAuthMethodsView()
/// }
/// ```
public struct MyAccountAuthMethodsView: View {
    // MARK: - Properties
    
    /// Shared navigation store that manages navigation paths throughout the auth methods flow.
    /// Used to handle navigation between different screens (QR code, OTP, enrollment, etc.)
    @StateObject private var navigationStore = NavigationStore.shared
    
    /// View model that manages the business logic for displaying authentication methods.
    /// Handles data fetching, state management, and error handling.
    @ObservedObject private var viewModel: MyAccountAuthMethodsViewModel

    // MARK: - Initialization
    
    /// Initializes the MyAccountAuthMethodsView.
    ///
    /// Creates a new instance of MyAccountAuthMethodsViewModel to manage
    /// the view's state and data loading.
    public init() {
        self.viewModel = MyAccountAuthMethodsViewModel()
    }

    // MARK: - Body
    
    /// The main view hierarchy for the authentication methods management screen.
    ///
    /// The view displays:
    /// 1. A loading spinner while data is being fetched
    /// 2. An error screen if data loading fails
    /// 3. A list of authentication method components (titles, subtitles, method cards) on success
    ///
    /// The view is wrapped in a NavigationStack to handle navigation to enrollment and management flows.
    public var body: some View {
        NavigationStack(path: $navigationStore.path) {
            ZStack {
                // Display loading state
                if viewModel.showLoader {
                    ProgressView()
                        .progressViewStyle(CircularProgressViewStyle())
                        .tint(Color("3C3C43", bundle: ResourceBundle.default))
                        .scaleEffect(1.5)
                        .frame(width: 50, height: 50)
                }
                // Display error state
                else if let errorViewModel = viewModel.errorViewModel {
                    ErrorScreen(viewModel: errorViewModel)
                        .padding()
                }
                // Display content state with list of authentication methods
                else {
                    ScrollView(showsIndicators: false) {
                        LazyVStack(alignment: .leading) {
                            // Iterate through view components (titles, subtitles, auth method cards)
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
                // Handle navigation to different screens based on Route
                .navigationDestination(for: Route.self) { route in
                    handleRoute(route: route)
                }
        }
        // Load authentication methods data when view appears
        .onAppear {
            Task {
                await viewModel.loadMyAccountAuthViewComponentData()
            }
        }
    }

    // MARK: - View Components
    
    /// Renders different types of authentication method view components.
    ///
    /// This function handles rendering of various component types:
    /// - Title text
    /// - Subtitle text
    /// - Authentication method cards with enrollment/deletion options
    /// - Empty state message when no factors are configured
    ///
    /// - Parameter component: The authentication method component to render
    /// - Returns: A SwiftUI View for the given component type
    @ViewBuilder
    private func authMethodView(_ component: MyAccountAuthViewComponentData) -> some View {
        switch component {
        // Render title text (e.g., "Authentication Methods")
        case .title(let text):
            Text(text)
                .foregroundStyle(Color("000000", bundle: ResourceBundle.default))
                .font(.system(size: 20, weight: .semibold))
        
        // Render subtitle text (e.g., "Add a way to verify your identity")
        case .subtitle(let text):
            Text(text)
                .foregroundStyle(Color("606060", bundle: ResourceBundle.default))
                .font(.system(size: 14, weight: .regular))
        
        // Render an authentication method card with action buttons
        case .authMethod(let viewModel):
            MyAccountAuthMethodView(viewModel: viewModel)
        
        // Render empty state when user has no configured authentication methods
        case .emptyFactors:
            HStack {
                // Info icon
                Image("info.circle.red", bundle: ResourceBundle.default)
                    .frame(width: 16, height: 16)
                
                // Empty state message
                Text("No factors configured")
                    .foregroundStyle(Color("CA3B2B", bundle: ResourceBundle.default))
                    .font(.system(size: 14).weight(.medium))
                Spacer()
            }
            .padding(.all, 12)
            .overlay {
                // Red border to highlight the empty state
                RoundedRectangle(cornerRadius: 16)
                    .stroke(Color("D9D9D9", bundle: ResourceBundle.default), lineWidth: 1)
            }
        }
    }

    // MARK: - Navigation Handling
    
    /// Handles navigation to different enrollment and management screens.
    ///
    /// Routes users to appropriate screens based on the selected authentication method type:
    /// - TOTP and Push QR code display
    /// - OTP verification screens
    /// - Saved authenticators list
    /// - Email/Phone enrollment
    /// - Recovery code enrollment
    ///
    /// - Parameter route: The navigation route indicating which screen to display
    /// - Returns: A SwiftUI View for the destination screen
    @ViewBuilder
    private func handleRoute(route: Route) -> some View {
        switch route {
        // Navigate to QR code screen for TOTP or Push enrollment
        case let .totpPushQRScreen(type):
            TOTPPushQRCodeView(viewModel: TOTPPushQRCodeViewModel(type: type))
        
        // Navigate to OTP verification screen for various enrollment types
        case let .otpScreen(type, emailOrPhoneNumber, totpEnrollmentChallege, phoneEnrollmentChallenge, emailEnrollmentChallenge):
            OTPView(viewModel: OTPViewModel(
                totpEnrollmentChallenge: totpEnrollmentChallege,
                emailEnrollmentChallenge: emailEnrollmentChallenge,
                phoneEnrollmentChallenge: phoneEnrollmentChallenge,
                type: type,
                emailOrPhoneNumber: emailOrPhoneNumber
            ))
        
        // Navigate to screen showing saved/enrolled authenticators for selection or deletion
        case let .filteredAuthListScreen(type, authMethods):
            SavedAuthenticatorsScreen(viewModel: SavedAuthenticatorsScreenViewModel(
                type: type,
                authenticationMethods: authMethods
            ))
        
        // Navigate to email or phone number enrollment screen
        case let .emailPhoneEnrollmentScreen(type):
            EmailPhoneEnrollmentView(viewModel: EmailPhoneEnrollmentViewModel(type: type))
        
        // Navigate to recovery code enrollment screen
        case .recoveryCodeScreen:
            RecoveryCodeEnrollmentView(viewModel: RecoveryCodeEnrollmentViewModel())
        }
    }
}
