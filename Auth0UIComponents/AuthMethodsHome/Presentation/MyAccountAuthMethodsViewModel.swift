
import Combine
import SwiftUI
import Auth0

/// Represents the different types of UI components that can be displayed in the authentication methods view.
///
/// This enum encapsulates the various visual elements that compose the authentication methods screen,
/// enabling a flexible, data-driven UI architecture where the view structure is determined by business logic
/// rather than hard-coded view hierarchies.
///
/// ## Component Types
///
/// - **title**: A section heading with prominent typography
/// - **subtitle**: Descriptive text that provides context below section titles
/// - **authMethod**: An interactive card representing a specific authentication method (TOTP, Push, Email, SMS, Recovery Codes)
/// - **emptyFactors**: A warning banner displayed when no authentication methods are configured
///
/// ## Design Pattern
///
/// Uses the enum with associated values pattern to create a type-safe, exhaustive component system.
/// This ensures that all possible component types are handled at compile time and allows each component
/// to carry its specific data.
///
/// ## Conformance
///
/// - **Hashable**: Enables use in SwiftUI's `ForEach` with `id: \.self` for efficient list rendering
///   and automatic diffing for performance optimization
///
/// ## Usage Example
///
/// ```swift
/// let components: [MyAccountAuthViewComponentData] = [
///     .title(text: "Verification methods"),
///     .subtitle(text: "Manage your 2FA methods"),
///     .authMethod(model: totpViewModel),
///     .authMethod(model: emailViewModel)
/// ]
/// ```
enum MyAccountAuthViewComponentData: Hashable {
    /// A prominent section heading
    /// - Parameter text: The heading text to display (e.g., "Verification methods")
    case title(text: String)

    /// Descriptive text providing context or instructions
    /// - Parameter text: The subtitle text to display (e.g., "Manage your 2FA methods")
    case subtitle(text: String)
    
    case createPasskey

    case signinMethods(model: MyAccountAuthMethodViewModel)

    /// An interactive authentication method card
    /// - Parameter model: The view model containing authentication method data and business logic
    case additionalVerificationMethods(model: MyAccountAuthMethodViewModel)

    /// A warning banner shown when no authentication factors are configured
    /// Prompts user to enroll in at least one MFA method for account security
    case emptyFactors
}

/// View model responsible for managing authentication methods data, state, and business logic.
///
/// `MyAccountAuthMethodsViewModel` orchestrates the loading, processing, and presentation of
/// authentication methods and MFA factors from the Auth0 backend. It handles API communication,
/// error scenarios, token refresh, and constructs the UI component hierarchy for the view layer.
///
/// ## Architecture
///
/// Follows MVVM pattern with clear separation of concerns:
/// - **Data Layer**: Uses use cases (GetFactorsUseCase, GetAuthMethodsUseCase) for API interactions
/// - **Business Logic**: Processes and transforms API responses into view-ready component models
/// - **State Management**: Publishes observable state changes via `@Published` properties
/// - **Error Handling**: Comprehensive error processing with retry logic and user-friendly messages
///
/// ## Threading
///
/// Marked with `@MainActor` to ensure all operations occur on the main thread, providing:
/// - Thread-safe access to UI-bound properties
/// - Safe updates to `@Published` properties from async contexts
/// - Elimination of race conditions in state management
///
/// ## Key Responsibilities
///
/// 1. **Authentication**: Manages access tokens and handles token refresh/reauthentication
/// 2. **Data Fetching**: Retrieves factors and authentication methods from Auth0 APIs
/// 3. **Data Processing**: Filters, maps, and transforms API responses into UI components
/// 4. **State Management**: Maintains loading, error, and content states
/// 5. **Error Handling**: Processes various error types (credentials, API, web auth) with appropriate recovery
///
/// ## Published Properties
///
/// The view model exposes three observable properties that drive UI updates:
/// - `viewComponents`: Array of UI components to render
/// - `errorViewModel`: Optional error state for displaying error screens
/// - `showLoader`: Boolean controlling loading indicator visibility
///
/// ## Usage Example
///
/// ```swift
/// @ObservedObject private var viewModel = MyAccountAuthMethodsViewModel()
///
/// // In view's onAppear:
/// Task {
///     await viewModel.loadMyAccountAuthViewComponentData()
/// }
/// ```
///
/// - Note: This class is marked `final` to prevent subclassing and enable compiler optimizations.
@MainActor
final class MyAccountAuthMethodsViewModel: ObservableObject {
    // MARK: - Dependencies

    /// Use case responsible for fetching available authentication factors from Auth0.
    ///
    /// Retrieves the list of factors (TOTP, Push, Email, SMS, Recovery Codes) that are
    /// enabled for the user's account. This determines which authentication methods can
    /// be enrolled and displayed in the UI.
    private let factorsUseCase: GetFactorsUseCaseable

    /// Use case responsible for fetching enrolled authentication methods from Auth0.
    ///
    /// Retrieves the user's currently enrolled authentication methods, including details
    /// like method type, enrollment status, and associated metadata (e.g., phone numbers,
    /// email addresses, authenticator names).
    private let authMethodsUseCase: GetAuthMethodsUseCaseable

    // MARK: - Published Properties

    /// Array of UI components to render in the authentication methods view.
    ///
    /// This property represents the complete UI structure as a flat array of components,
    /// constructed from the API data. The view layer renders these components in order,
    /// creating the visual hierarchy of titles, subtitles, and authentication method cards.
    ///
    /// The array is rebuilt on each successful data load to reflect the current state.
    ///
    /// - Note: Published on the main thread; updates trigger view re-rendering automatically.
    @Published var viewComponents: [MyAccountAuthViewComponentData] = []

    /// Optional error view model for displaying error states.
    ///
    /// When non-nil, indicates that an error occurred during data loading or authentication.
    /// The error view model contains:
    /// - User-friendly error message
    /// - Retry action callback
    /// - Error-specific UI configuration
    ///
    /// Set to `nil` when starting a new load operation or when data loads successfully.
    ///
    /// - Note: Published on the main thread; setting this to non-nil triggers error screen display.
    @Published var errorViewModel: ErrorScreenViewModel? = nil

    /// Boolean indicating whether to display the loading spinner.
    ///
    /// Controls the visibility of the loading state in the UI. Set to:
    /// - `true`: When starting data load, during token refresh, or during reauthentication
    /// - `false`: When data loads successfully or when an error occurs
    ///
    /// Initialized to `true` to show loading state immediately when view appears.
    ///
    /// - Note: Published on the main thread; updates control loading indicator visibility.
    @Published var showLoader: Bool = true

    // MARK: - Private Properties

    /// SDK dependencies container providing Auth0 configuration and services.
    ///
    /// Contains essential configuration including:
    /// - Auth0 domain and client ID
    /// - Token provider for credential management
    /// - Audience for API access
    /// - Web authentication session configuration
    ///
    /// Injected during initialization to enable testability and configuration flexibility.
    private let dependencies: Auth0UIComponentsSDKInitializer
    
    // MARK: - Initialization

    /// Creates a new instance of the authentication methods view model.
    ///
    /// Initializes the view model with its required dependencies for API communication,
    /// business logic execution, and Auth0 integration. All dependencies have default
    /// values for convenient initialization while maintaining testability through
    /// dependency injection.
    ///
    /// ## Dependency Injection
    ///
    /// This initializer uses the dependency injection pattern with default parameters,
    /// providing flexibility for different contexts:
    /// - **Production**: Uses default values for real Auth0 API integration
    /// - **Testing**: Inject mock implementations for unit testing
    /// - **Preview**: Inject stub implementations for SwiftUI previews
    ///
    /// ## Default Dependencies
    ///
    /// - `factorsUseCase`: Fresh instance of `GetFactorsUseCase()` for fetching available factors
    /// - `authMethodsUseCase`: Fresh instance of `GetAuthMethodsUseCase()` for fetching enrolled methods
    /// - `dependencies`: Shared SDK initializer (`.shared`) containing Auth0 configuration
    ///
    /// ## Parameters
    ///
    /// - Parameter factorsUseCase: Use case for fetching available authentication factors from Auth0
    /// - Parameter authMethodsUseCase: Use case for fetching enrolled authentication methods from Auth0
    /// - Parameter dependencies: SDK configuration containing Auth0 domain, client ID, token provider, and session
    ///
    /// ## Usage Examples
    ///
    /// ### Production Usage
    /// ```swift
    /// let viewModel = MyAccountAuthMethodsViewModel()
    /// // Uses default dependencies with real Auth0 integration
    /// ```
    ///
    /// ### Testing Usage
    /// ```swift
    /// let mockFactorsUseCase = MockGetFactorsUseCase()
    /// let mockAuthMethodsUseCase = MockGetAuthMethodsUseCase()
    /// let mockDependencies = MockAuth0UIComponentsSDKInitializer()
    ///
    /// let viewModel = MyAccountAuthMethodsViewModel(
    ///     factorsUseCase: mockFactorsUseCase,
    ///     authMethodsUseCase: mockAuthMethodsUseCase,
    ///     dependencies: mockDependencies
    /// )
    /// ```
    init(factorsUseCase: GetFactorsUseCaseable = GetFactorsUseCase(),
         authMethodsUseCase: GetAuthMethodsUseCaseable = GetAuthMethodsUseCase(),
         dependencies: Auth0UIComponentsSDKInitializer = .shared) {
        self.factorsUseCase = factorsUseCase
        self.authMethodsUseCase = authMethodsUseCase
        self.dependencies = dependencies
    }
    
    // MARK: - Public Methods

    /// Loads authentication factors and methods from Auth0, then constructs the UI component hierarchy.
    ///
    /// This is the primary data-loading method that orchestrates the complete flow of fetching,
    /// processing, and preparing authentication data for display. It handles authentication,
    /// parallel API calls, data transformation, and error scenarios.
    ///
    /// ## Execution Flow
    ///
    /// 1. **State Reset**: Clears previous error state and components, shows loading indicator
    /// 2. **Authentication**: Fetches or refreshes access token with required scopes
    /// 3. **Parallel API Calls**: Simultaneously fetches factors and authentication methods for performance
    /// 4. **Data Processing**: Filters and maps API responses to supported authentication types
    /// 5. **Component Building**: Constructs UI component array based on available factors
    /// 6. **State Update**: Updates published properties to trigger UI rendering
    ///
    /// ## Required OAuth Scopes
    ///
    /// - `openid`: Required for OpenID Connect authentication
    /// - `read:me:factors`: Permission to read user's available MFA factors
    /// - `read:me:authentication_methods`: Permission to read user's enrolled authentication methods
    ///
    /// ## Component Construction Logic
    ///
    /// ### When Factors Exist
    /// Builds a component array containing:
    /// 1. Title: "Verification methods"
    /// 2. Subtitle: "Manage your 2FA methods"
    /// 3. Authentication Method Cards: One card per factor with filtered enrolled methods
    ///
    /// ### When No Factors Available
    /// Shows a single empty state component (`.emptyFactors`) prompting user action
    ///
    /// ## Performance Optimization
    ///
    /// Uses `async let` for concurrent execution of independent API calls:
    /// - Factors and authentication methods are fetched in parallel
    /// - Reduces total loading time significantly (network latency overlap)
    /// - Results are awaited together using tuple destructuring
    ///
    /// ## Error Handling
    ///
    /// Errors are caught and delegated to the `handle(error:scope:retryCallback:)` method, which:
    /// - Determines error type (credentials, API, web auth)
    /// - Attempts automatic recovery (e.g., token refresh, reauthentication)
    /// - Shows user-friendly error messages with retry options
    /// - Provides automatic retry callback that re-executes this method
    ///
    /// ## Threading
    ///
    /// Executes entirely on the main actor due to `@MainActor` class annotation:
    /// - Safe to update `@Published` properties directly
    /// - No need for explicit `DispatchQueue.main.async` calls
    /// - Ensures thread-safe state updates throughout async execution
    ///
    /// ## Usage Example
    ///
    /// ```swift
    /// .onAppear {
    ///     Task {
    ///         await viewModel.loadMyAccountAuthViewComponentData()
    ///     }
    /// }
    /// ```
    ///
    /// - Note: This method is designed to be called multiple times (e.g., on view appearance, pull-to-refresh, retry).
    ///   Each call resets state and performs a fresh data load.
    func loadMyAccountAuthViewComponentData() async {
        // Reset state for fresh load
        errorViewModel = nil // Clear any previous error state
        self.viewComponents = [] // Clear previous components to show loading state
        showLoader = true // Display loading spinner

        do {
            // MARK: Authentication - Fetch access token with required scopes
            let apiCredentials = try await dependencies.tokenProvider.fetchAPICredentials(
                audience: dependencies.audience,
                scope: "openid read:me:factors read:me:authentication_methods"
            )

            // MARK: Parallel API Calls - Fetch factors and methods concurrently for performance
            async let factorsResponse = factorsUseCase.execute(
                request: GetFactorsRequest(token: apiCredentials.accessToken, domain: dependencies.domain)
            )
            async let authMethodsResponse = authMethodsUseCase.execute(
                request: GetAuthMethodsRequest(token: apiCredentials.accessToken, domain: dependencies.domain)
            )

            // Await both responses simultaneously (structured concurrency)
            let (authMethods, factors) = try await (authMethodsResponse, factorsResponse)

            // MARK: Data Transformation - Filter factors to only supported types
            // Maps raw factor types to AuthMethodType enum, discarding unsupported types
            let supportedFactors = factors.compactMap { AuthMethodType(rawValue: $0.type) }

            // Hide loading indicator now that data is ready
            showLoader = false
            
            // Build component array with title, subtitle, and method cards
            var viewComponents: [MyAccountAuthViewComponentData] = []
            if authMethods.filter({ $0.type == "passkey" }).isEmpty == true {
                viewComponents.append(.createPasskey)
            }
            viewComponents.append(.title(text: "Sign-in methods"))
            viewComponents.append(.signinMethods(model: MyAccountAuthMethodViewModel(authMethods: authMethods.filter { $0.type == AuthMethodType.passkey.rawValue }, type: .passkey, dependencies: dependencies)))
            viewComponents.append(.title(text: "Verification methods"))
            viewComponents.append(.subtitle(text: "Manage your 2FA methods"))

            // MARK: Component Construction - Build UI component hierarchy
            if supportedFactors.isEmpty == false {
                // Create an authentication method card for each supported factor
                for factor in supportedFactors  {
                    // Filter auth methods to only those matching current factor type
                    let filteredAuthMethods = authMethods.filter { $0.type == factor.rawValue }

                    // Create view model for this specific auth method card
                    viewComponents.append(.additionalVerificationMethods(model: MyAccountAuthMethodViewModel(
                        authMethods: filteredAuthMethods,
                        type: factor,
                        dependencies: dependencies
                    )))
                }

                // Update published property to trigger UI render
                self.viewComponents = viewComponents
            } else {
                // No factors available - show empty state warning
                self.viewComponents = [.emptyFactors]
            }
        } catch  {
            // MARK: Error Handling - Delegate to comprehensive error handler with retry logic
            await handle(error: error, scope: "openid read:me:factors read:me:authentication_methods") { [weak self] in
                Task {
                    // Retry callback: re-execute this method if user taps retry button
                    await self?.loadMyAccountAuthViewComponentData()
                }
            }
        }
    }
        
    // MARK: - Private Methods

    /// Handles errors with type-specific recovery strategies and user-friendly error presentation.
    ///
    /// This comprehensive error handler processes different error types that can occur during
    /// authentication and data loading, attempting automatic recovery where possible and
    /// presenting appropriate error messages to users when manual intervention is required.
    ///
    /// ## Error Types Handled
    ///
    /// ### 1. CredentialsManagerError
    /// Occurs when there are issues with access tokens:
    /// - **MFA Required**: Token is expired and requires MFA challenge
    ///   - **Automatic Recovery**: Launches web auth flow for reauthentication
    ///   - Shows loading indicator during reauthentication
    ///   - Stores new credentials and retries original operation on success
    ///   - Recursively handles any errors during reauthentication
    /// - **Other Credential Errors**: Token missing, invalid, or refresh failed
    ///   - Shows error screen with retry option
    ///
    /// ### 2. MyAccountError
    /// Occurs when Auth0 Management API calls fail:
    /// - Network errors (timeout, no connection)
    /// - API errors (rate limit, server error)
    /// - Authorization errors (insufficient permissions)
    /// - Shows error screen with user-friendly message and retry option
    ///
    /// ### 3. WebAuthError
    /// Occurs during web authentication flows:
    /// - User cancelled authentication
    /// - Browser/webview errors
    /// - OAuth callback errors
    /// - Shows error screen with user-friendly message and retry option
    ///
    /// ## Error Recovery Flow
    ///
    /// ```
    /// Error Occurs
    ///     ↓
    /// Determine Error Type
    ///     ↓
    /// ├─ MFA Required? → Launch WebAuth → Store Credentials → Retry Operation
    /// ├─ Credentials Error? → Show Error Screen with Retry
    /// ├─ API Error? → Show Error Screen with Retry
    /// └─ WebAuth Error? → Show Error Screen with Retry
    /// ```
    ///
    /// ## Retry Mechanism
    ///
    /// The retry callback parameter enables automatic recovery:
    /// - Passed to error view models for user-initiated retry
    /// - Called automatically after successful reauthentication
    /// - Typically re-executes the original operation (e.g., `loadMyAccountAuthViewComponentData()`)
    /// - Uses `[weak self]` capture to prevent retain cycles
    ///
    /// ## Threading Considerations
    ///
    /// Marked with `@MainActor` to ensure:
    /// - Safe updates to `@Published` properties (showLoader, errorViewModel)
    /// - UI updates occur on the main thread
    /// - Consistent with the class-level `@MainActor` annotation
    ///
    /// ## Parameters
    ///
    /// - Parameter error: The error to handle and recover from
    /// - Parameter scope: OAuth scopes to request during reauthentication (used for MFA recovery)
    /// - Parameter retryCallback: Closure to execute after successful recovery or when user taps retry
    ///
    /// ## Usage Example
    ///
    /// ```swift
    /// do {
    ///     try await performAPICall()
    /// } catch {
    ///     await handle(error: error, scope: "openid read:me:factors") {
    ///         Task {
    ///             await self?.performAPICall() // Retry on recovery/user request
    ///         }
    ///     }
    /// }
    /// ```
    ///
    /// - Note: This method may recursively call itself when handling reauthentication errors,
    ///   ensuring all error scenarios are properly handled until resolution or final error display.
    @MainActor func handle(error: Error,
                           scope: String,
                           retryCallback: @escaping () -> Void) async {
        // Hide loading indicator before showing error (unless we're going to reauth)
        showLoader = false

        // MARK: Credentials Manager Error Handling
        if let error = error as? CredentialsManagerError {
            let uiComponentError = Auth0UIComponentError.handleCredentialsManagerError(error: error)

            // Special case: MFA required - attempt automatic reauthentication
            if case .mfaRequired = uiComponentError {
                showLoader = true // Show loading during reauthentication

                do {
                    // Launch web authentication flow to get fresh credentials with MFA
                    let credentials = try await Auth0.webAuth(
                        clientId: dependencies.clientId,
                        domain: dependencies.domain,
                        session: dependencies.session
                    )
                    .audience(dependencies.audience)
                    .scope(scope)
                    .start()

                    // Store the new credentials for future use
                    await dependencies.tokenProvider.store(
                        apiCredentials: APICredentials(from: credentials),
                        for: dependencies.audience
                    )

                    showLoader = false
                    // Retry the original operation with new credentials
                    retryCallback()
                } catch  {
                    // Reauthentication failed - recursively handle the new error
                    await handle(error: error,
                                 scope: scope,
                                 retryCallback: retryCallback)
                }
            } else {
                // Other credential errors - show error screen with retry option
                errorViewModel = uiComponentError.errorViewModel(completion: {
                    retryCallback()
                })
            }
        }
        // MARK: My Account API Error Handling
        else if let error  = error as? MyAccountError {
            // Transform Auth0 API error into user-friendly UI component error
            let uiComponentError = Auth0UIComponentError.handleMyAccountAuthError(error: error)
            errorViewModel = uiComponentError.errorViewModel(completion: {
                retryCallback()
            })
        }
        // MARK: Web Authentication Error Handling
        else if let error = error as? WebAuthError {
            // Transform web auth error into user-friendly UI component error
            let uiComponentError = Auth0UIComponentError.handleWebAuthError(error: error)
            errorViewModel = uiComponentError.errorViewModel {
                retryCallback()
            }
        }
    }
}
