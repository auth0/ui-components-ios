import SwiftUI

/// The main view for managing authentication methods and Multi-Factor Authentication (MFA) enrollment.
///
/// `MyAccountAuthMethodsView` serves as the central hub for authentication method management,
/// providing a comprehensive interface for users to secure their accounts with multiple verification methods.
///
/// ## Features
///
/// This view provides functionality for:
/// - **Viewing** all enrolled authentication methods including:
///   - TOTP (Time-based One-Time Password) authenticators
///   - Push notifications via mobile apps
///   - Email verification
///   - SMS verification
///   - Recovery codes for account recovery
/// - **Enrolling** in new authentication methods with guided flows
/// - **Deleting** existing authentication methods (with appropriate safeguards)
/// - **Managing** recovery codes for emergency access
///
/// ## Architecture
///
/// The view follows MVVM architecture:
/// - Uses `MyAccountAuthMethodsViewModel` for business logic and state management
/// - Leverages `NavigationStore` for coordinating navigation between screens
/// - Supports declarative routing via SwiftUI's `NavigationStack`
///
/// ## State Management
///
/// The view handles three primary states:
/// 1. **Loading**: Displays a progress indicator while fetching data
/// 2. **Error**: Shows an error screen if data loading fails
/// 3. **Content**: Presents the list of authentication methods when data loads successfully
///
/// ## Usage Example
///
/// ```swift
/// import SwiftUI
/// import Auth0UIComponents
///
/// struct ContentView: View {
///     var body: some View {
///         MyAccountAuthMethodsView()
///     }
/// }
/// ```
///
/// ## Navigation Flow
///
/// The view can navigate to:
/// - QR code scanning for TOTP/Push enrollment
/// - OTP verification screens
/// - Email/Phone enrollment forms
/// - Recovery code generation and display
/// - Saved authenticators management
///
/// - Note: This view automatically handles data loading on appearance and manages its own lifecycle.
/// - Important: Requires proper Auth0 configuration and authentication session to function correctly.
public struct MyAccountAuthMethodsView: View {
    // MARK: - Properties
    
    /// Shared navigation store that manages the navigation path stack throughout the authentication methods flow.
    ///
    /// This singleton instance coordinates navigation state across the entire auth methods feature,
    /// enabling deep linking and programmatic navigation between screens. The navigation store maintains
    /// a stack-based navigation path that supports:
    /// - Forward navigation to enrollment screens (QR code, OTP, email/phone input)
    /// - Backward navigation with proper state cleanup
    /// - Deep linking to specific authentication method screens
    ///
    /// - Note: Uses `@StateObject` to ensure the store persists across view updates and is properly
    ///   initialized only once for this view instance.
    @StateObject private var navigationStore = NavigationStore.shared
    
    /// View model that encapsulates the business logic and state for authentication methods management.
    ///
    /// This view model is responsible for:
    /// - **Data Loading**: Fetching authentication methods from the Auth0 backend
    /// - **State Management**: Managing loading, error, and content states
    /// - **Component Building**: Constructing the UI component hierarchy (titles, subtitles, method cards)
    /// - **Error Handling**: Processing API errors and presenting user-friendly error messages
    ///
    /// The view model exposes observable properties that trigger UI updates:
    /// - `showLoader`: Boolean indicating whether to display the loading spinner
    /// - `errorViewModel`: Optional error view model for displaying error states
    /// - `viewComponents`: Array of UI components to render in the content state
    ///
    /// - Note: Uses `@ObservedObject` because the view model is created during initialization
    ///   rather than being injected, ensuring proper observation of published properties.
    @ObservedObject private var viewModel: MyAccountAuthMethodsViewModel

    // MARK: - Initialization
    
    /// Creates a new instance of the authentication methods management view.
    ///
    /// This initializer sets up the view with a fresh view model instance that will handle
    /// all business logic, data fetching, and state management. The view model is automatically
    /// configured with the necessary dependencies for communicating with Auth0 services.
    ///
    /// ## Initialization Process
    ///
    /// 1. Creates a new `MyAccountAuthMethodsViewModel` instance
    /// 2. The view model prepares its internal state for data loading
    /// 3. The view becomes ready to fetch and display authentication methods
    ///
    /// - Note: The actual data loading is triggered in the `onAppear` modifier, not during initialization.
    ///   This ensures data is only fetched when the view is actually presented to the user.
    ///
    /// ## Example
    ///
    /// ```swift
    /// let authMethodsView = MyAccountAuthMethodsView()
    /// // View is now ready to be presented
    /// ```
    public init() {
        self.viewModel = MyAccountAuthMethodsViewModel()
    }

    // MARK: - Body
    
    /// The main view hierarchy that composes the authentication methods management interface.
    ///
    /// This computed property builds the complete UI hierarchy, handling all possible view states
    /// and coordinating navigation flows.
    ///
    /// ## View Composition
    ///
    /// The body is composed of several layers:
    ///
    /// 1. **NavigationStack**: The outermost container that enables navigation between screens
    ///    - Binds to `navigationStore.path` for centralized navigation state
    ///    - Configures navigation destinations via `.navigationDestination(for: Route.self)`
    ///
    /// 2. **ZStack**: Manages the three mutually exclusive view states:
    ///    - **Loading State**: Shows a centered progress indicator while fetching data
    ///    - **Error State**: Displays an error screen with retry options if loading fails
    ///    - **Content State**: Presents the scrollable list of authentication methods
    ///
    /// 3. **Navigation Configuration**: Sets up the navigation bar with title and platform-specific styling
    ///
    /// 4. **Lifecycle Hook**: Uses `.onAppear` to trigger data loading when the view becomes visible
    ///
    /// ## State-Specific UI
    ///
    /// ### Loading State (`viewModel.showLoader == true`)
    /// - Displays a circular progress indicator
    /// - Uses brand color tint with 1.5x scale for visibility
    /// - Centered in the screen with 50x50 frame
    ///
    /// ### Error State (`viewModel.errorViewModel != nil`)
    /// - Shows the `ErrorScreen` component with error details
    /// - Provides user-friendly error message and retry options
    /// - Includes padding for proper spacing
    ///
    /// ### Content State (default)
    /// - Renders a scrollable vertical list of components
    /// - Uses `LazyVStack` for performance optimization with large lists
    /// - Displays titles, subtitles, auth method cards, and empty states
    /// - Applies consistent 16-point padding on all sides
    ///
    /// ## Navigation Bar
    ///
    /// - Title: "Login & Security"
    /// - Display Mode: Inline on iOS/tvOS/watchOS for consistent header sizing
    /// - macOS: Uses default navigation title styling
    ///
    /// ## Data Loading
    ///
    /// - Automatically loads authentication methods when view appears
    /// - Uses async/await for non-blocking data fetching
    /// - Triggers view model's `loadMyAccountAuthViewComponentData()` method
    ///
    /// - Note: The view automatically handles state transitions between loading, error, and content states
    ///   based on the view model's published properties.
    public var body: some View {
        NavigationStack(path: $navigationStore.path) {
            ZStack {
                // MARK: Loading State
                // Shows a branded progress indicator while fetching authentication methods from the server
                if viewModel.showLoader {
                    ProgressView()
                        .progressViewStyle(CircularProgressViewStyle())
                        .tint(Color("3C3C43", bundle: ResourceBundle.default)) // Brand-compliant dark gray
                        .scaleEffect(1.5) // Enlarged for better visibility
                        .frame(width: 50, height: 50) // Fixed size container
                }
                // MARK: Error State
                // Displays an error screen with descriptive message and retry option when data loading fails
                else if let errorViewModel = viewModel.errorViewModel {
                    ErrorScreen(viewModel: errorViewModel)
                        .padding() // Adds spacing from screen edges
                }
                // MARK: Content State
                // Presents the main list of authentication methods with supporting UI elements
                else {
                    ScrollView(showsIndicators: false) { // Hides scroll indicators for cleaner appearance
                        LazyVStack(alignment: .leading) { // Lazy loading for performance; left-aligned content
                            // Dynamically render each component (titles, subtitles, method cards, empty state)
                            // based on the view model's computed component array
                            ForEach(viewModel.viewComponents, id: \.self) { component in
                                authMethodView(component)
                            }
                        }.padding(.all, 16) // Consistent 16pt padding on all sides for spacing
                    }
                }
            }
            .navigationTitle(Text("Login & Security")) // Sets the navigation bar title
            #if !os(macOS)
                // iOS, tvOS, watchOS: Use inline display mode for consistent, compact navigation bar
                .navigationBarTitleDisplayMode(.inline)
            #endif
                // MARK: Navigation Destination Handler
                // Routes to appropriate screens based on Route enum values
                // Handles all navigation flows: enrollment, verification, management
                .navigationDestination(for: Route.self) { route in
                    handleRoute(route: route)
                }
        }
        // MARK: Lifecycle Hook
        // Triggers data loading when view appears on screen
        // Uses Task for async execution without blocking the main thread
        .onAppear {
            Task {
                // Fetches authentication methods from Auth0 and builds the component hierarchy
                await viewModel.loadMyAccountAuthViewComponentData()
            }
        }
    }

    // MARK: - View Components
    
    /// Dynamically renders authentication method UI components based on their type.
    ///
    /// This builder function acts as a view factory, creating the appropriate SwiftUI view
    /// for each component type defined in the view model's component hierarchy. It enables
    /// flexible, data-driven UI composition where the view structure is determined by the
    /// backend data and business logic.
    ///
    /// ## Supported Component Types
    ///
    /// ### `.title(String)`
    /// Renders a section heading with large, bold typography
    /// - Font: System font, 20pt, semibold weight
    /// - Color: Brand black (`#000000`)
    /// - Usage: Section headers like "Authentication Methods", "Recovery Options"
    ///
    /// ### `.subtitle(String)`
    /// Renders descriptive text below section titles
    /// - Font: System font, 14pt, regular weight
    /// - Color: Medium gray (`#606060`) for reduced emphasis
    /// - Usage: Explanatory text like "Add a way to verify your identity"
    ///
    /// ### `.authMethod(MyAccountAuthMethodViewModel)`
    /// Renders an interactive authentication method card
    /// - Displays method icon, name, and status
    /// - Includes action buttons (Add/Delete) based on enrollment state
    /// - Handles user interactions for enrollment or removal
    /// - Usage: Individual TOTP, Push, Email, SMS, or Recovery Code cards
    ///
    /// ### `.emptyFactors`
    /// Renders a warning banner when no authentication methods are configured
    /// - Shows info icon and error message
    /// - Styled with red accent color to indicate action required
    /// - Border: Light gray with rounded corners
    /// - Usage: Displayed when user has not enrolled any MFA methods
    ///
    /// ## Design Pattern
    ///
    /// Uses the ViewBuilder pattern to enable compile-time type safety and efficient view composition.
    /// The switch statement exhaustively handles all possible component types, ensuring that new
    /// component types must be explicitly handled at compile time.
    ///
    /// - Parameter component: The component data to render, encapsulating type and associated values
    /// - Returns: A type-erased SwiftUI View configured for the specific component type
    ///
    /// - Note: This function is marked `private` as it's an internal implementation detail.
    ///   External consumers should not need to call this directly.
    @ViewBuilder
    private func authMethodView(_ component: MyAccountAuthViewComponentData) -> some View {
        switch component {
        // MARK: Title Component
        // Renders a prominent section heading with bold typography
        case .createPasskey(let viewModel):
          EnrollPasskeyView(viewModel: viewModel)
                .padding(.bottom, 24)
        case .signinMethods(let viewModel):
            MyAccountAuthMethodView(viewModel: viewModel)
                .padding(.bottom, 48)
        case .title(let text):
            Text(text)
                .foregroundStyle(Color("000000", bundle: ResourceBundle.default)) // Pure black for maximum contrast
                .font(.system(size: 20, weight: .semibold)) // Large, bold font for hierarchy

        // MARK: Subtitle Component
        // Renders secondary descriptive text with reduced visual weight
        case .subtitle(let text):
            Text(text)
                .foregroundStyle(Color("606060", bundle: ResourceBundle.default)) // Medium gray for subtlety
                .font(.system(size: 14, weight: .regular)) // Standard body text size

        // MARK: Authentication Method Card
        // Renders an interactive card for a specific authentication method
        // Delegates to MyAccountAuthMethodView for the complete card UI and interaction handling
        case .additionalVerificationMethods(let viewModel):
            MyAccountAuthMethodView(viewModel: viewModel)

        // MARK: Empty State Warning
        // Renders an alert-style banner when user has no MFA methods configured
        // Encourages user to enroll in at least one authentication method for security
        case .emptyFactors:
            EmptyFactorsView()
        }
    }

    // MARK: - Navigation Handling

    /// Routes navigation requests to the appropriate destination screens.
    ///
    /// This function serves as the central navigation router for the authentication methods feature,
    /// translating `Route` enum values into concrete view instances. It ensures type-safe navigation
    /// and proper data passing between screens in the enrollment and management flows.
    ///
    /// ## Navigation Routes
    ///
    /// ### `.totpPushQRScreen(AuthMethodType)`
    /// Navigates to the QR code display screen for:
    /// - **TOTP enrollment**: Shows QR code to scan with authenticator apps (Google Authenticator, Authy, etc.)
    /// - **Push notification enrollment**: Shows QR code for pairing mobile push notification apps
    ///
    /// The screen handles QR code generation, display, and provides fallback manual entry codes.
    ///
    /// ### `.otpScreen(type, emailOrPhoneNumber, challenges...)`
    /// Navigates to the OTP verification screen with context-specific configuration:
    /// - **TOTP verification**: Validates 6-digit codes from authenticator apps
    /// - **Email verification**: Confirms codes sent to user's email
    /// - **SMS verification**: Confirms codes sent via text message
    ///
    /// Parameters include enrollment challenges and contact information for proper verification flow.
    ///
    /// ### `.filteredAuthListScreen(type, authMethods)`
    /// Navigates to a filtered list of saved authenticators for a specific method type.
    /// Enables users to:
    /// - View all enrolled instances of a method (e.g., multiple TOTP apps)
    /// - Select which authenticator to use
    /// - Delete specific authenticators
    ///
    /// ### `.emailPhoneEnrollmentScreen(AuthMethodType)`
    /// Navigates to the enrollment form for email or phone-based authentication:
    /// - **Email enrollment**: Form to enter and verify email address
    /// - **Phone enrollment**: Form to enter phone number with country code selection
    ///
    /// Validates input and initiates the verification code sending process.
    ///
    /// ### `.recoveryCodeScreen`
    /// Navigates to the recovery code management screen:
    /// - Generates a set of single-use recovery codes
    /// - Displays codes with copy and download options
    /// - Provides guidance on secure storage
    /// - Essential for account recovery if primary methods are unavailable
    ///
    /// ## Implementation Notes
    ///
    /// - Uses `@ViewBuilder` for efficient, type-safe view composition
    /// - Each route instantiates its destination view with required view models and data
    /// - View models are initialized inline with data from the route's associated values
    /// - The navigation stack automatically handles back navigation and state management
    ///
    /// - Parameter route: The navigation route enum value containing destination type and associated data
    /// - Returns: A type-erased SwiftUI View configured for the specified route
    ///
    /// - Note: This function is private as it's an internal routing mechanism. External navigation
    ///   should occur through the shared `NavigationStore`.
    @ViewBuilder
    private func handleRoute(route: Route) -> some View {
        switch route {
        // MARK: QR Code Route
        // Displays QR code for TOTP or Push authenticator enrollment
        // User scans QR code with their authenticator app to complete pairing
        case let .totpPushQRScreen(type):
            TOTPPushQRCodeView(viewModel: TOTPPushQRCodeViewModel(type: type))

        // MARK: OTP Verification Route
        // Shows one-time password input screen for verifying enrollment or authentication
        // Handles TOTP, Email OTP, and SMS OTP verification flows
        // Associated values provide context (email/phone) and challenge data for verification
        case let .otpScreen(type, emailOrPhoneNumber, totpEnrollmentChallege, phoneEnrollmentChallenge, emailEnrollmentChallenge):
            OTPView(viewModel: OTPViewModel(
                totpEnrollmentChallenge: totpEnrollmentChallege,
                emailEnrollmentChallenge: emailEnrollmentChallenge,
                phoneEnrollmentChallenge: phoneEnrollmentChallenge,
                type: type,
                emailOrPhoneNumber: emailOrPhoneNumber
            ))

        // MARK: Saved Authenticators List Route
        // Displays all enrolled authenticators of a specific type
        // Allows users to view details and delete individual authenticators
        // Useful when multiple instances of the same auth method exist (e.g., multiple TOTP apps)
        case let .filteredAuthListScreen(type, authMethods):
            SavedAuthenticatorsScreen(viewModel: SavedAuthenticatorsScreenViewModel(
                type: type,
                authenticationMethods: authMethods
            ))

        // MARK: Email/Phone Enrollment Route
        // Shows input form for entering email address or phone number
        // Includes validation and initiates code sending for verification
        // Distinct flows for email vs phone (country code selector for phone)
        case let .emailPhoneEnrollmentScreen(type):
            EmailPhoneEnrollmentView(viewModel: EmailPhoneEnrollmentViewModel(type: type))

        // MARK: Recovery Code Route
        // Generates and displays backup recovery codes for emergency account access
        // Users should save these codes securely for use when primary auth methods fail
        // Codes are typically single-use and regeneratable
        case .recoveryCodeScreen:
            RecoveryCodeEnrollmentView(viewModel: RecoveryCodeEnrollmentViewModel())
        case .enrollPasskeyScreen:
            PasskeysEnrollmentView(viewModel: PasskeysEnrollmentViewModel())
        }
    }
}
