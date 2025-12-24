import Auth0
import Foundation

/// A structured request object containing all necessary parameters to fetch authentication methods.
///
/// `GetAuthMethodsRequest` encapsulates the data required to make an authenticated API call
/// to Auth0's MyAccount endpoint for retrieving the user's enrolled authentication methods.
/// This structure follows the Request-Response pattern, decoupling execution logic from data.
///
/// ## Design Pattern
///
/// Uses the **Parameter Object** pattern to:
/// - Bundle related parameters into a single, cohesive object
/// - Simplify method signatures (one parameter instead of multiple)
/// - Enable easy addition of new parameters without breaking existing code
/// - Improve testability by making request data explicit and immutable
///
/// ## Security Considerations
///
/// The access token should have the following scopes:
/// - `openid`: Required for OpenID Connect authentication
/// - `read:me:authentication_methods`: Permission to read user's enrolled authentication methods
///
/// ## Usage Example
///
/// ```swift
/// let request = GetAuthMethodsRequest(
///     token: "eyJhbGciOiJSUzI1NiIsInR5cCI6IkpXVCJ9...",
///     domain: "my-tenant.auth0.com"
/// )
///
/// let authMethods = try await useCase.execute(request: request)
/// ```
///
/// - Note: This struct is immutable (`let` properties) to ensure thread safety and prevent
///   accidental modification during async operations.
struct GetAuthMethodsRequest {
    /// The OAuth 2.0 access token required to authorize the API request.
    ///
    /// This token must be valid and include the necessary scopes to access the MyAccount
    /// authentication methods endpoint. The token is typically obtained through:
    /// - Initial user authentication (login flow)
    /// - Token refresh from the credentials manager
    /// - Web authentication with required scopes
    ///
    /// **Format**: JWT (JSON Web Token) string
    ///
    /// **Required Scopes**:
    /// - `openid`
    /// - `read:me:authentication_methods`
    ///
    /// - Important: Never log or expose this token as it grants access to sensitive user data.
    let token: String

    /// The Auth0 tenant domain where the user's account is hosted.
    ///
    /// The domain identifies which Auth0 tenant to query for authentication methods.
    /// This is the base URL for all Auth0 API requests for this tenant.
    ///
    /// **Format**: Domain string without protocol
    /// - ✅ Correct: `"my-tenant.auth0.com"` or `"my-tenant.us.auth0.com"`
    /// - ❌ Incorrect: `"https://my-tenant.auth0.com"` (includes protocol)
    ///
    /// **Examples**:
    /// - US tenant: `"my-company.auth0.com"`
    /// - EU tenant: `"my-company.eu.auth0.com"`
    /// - AU tenant: `"my-company.au.auth0.com"`
    /// - Custom domain: `"auth.mycompany.com"`
    let domain: String
}

/// Defines the contract for fetching a user's enrolled authentication methods from Auth0.
///
/// `GetAuthMethodsUseCaseable` is a protocol that abstracts the logic for retrieving the list
/// of authentication methods that a user has enrolled for their account. This protocol follows
/// the **Use Case** pattern from Clean Architecture, encapsulating a single business operation.
///
/// ## Architecture Role
///
/// - **Domain Layer**: Part of the business logic layer, independent of frameworks
/// - **Single Responsibility**: Retrieves enrolled authentication methods only
/// - **Dependency Inversion**: UI depends on this protocol, not concrete implementations
/// - **Testability**: Protocol enables easy mocking for unit tests
///
/// ## What Are Authentication Methods?
///
/// Authentication methods are the user's enrolled MFA (Multi-Factor Authentication) factors:
/// - **TOTP**: Time-based one-time passwords (Google Authenticator, Authy, etc.)
/// - **Push**: Push notification-based authentication via Guardian app
/// - **Email**: Email-based one-time passwords
/// - **SMS**: SMS-based one-time passwords
/// - **Recovery Code**: Backup codes for emergency access
///
/// ## Data Source
///
/// Fetches data from Auth0's **MyAccount API**, which provides user-specific account
/// management capabilities. The endpoint returns detailed information about each enrolled method:
/// - Method ID and type
/// - Enrollment status (confirmed vs. pending)
/// - Associated metadata (email address, phone number, device name, etc.)
/// - Creation and last-used timestamps
///
/// ## Usage Example
///
/// ```swift
/// // In production
/// let useCase: GetAuthMethodsUseCaseable = GetAuthMethodsUseCase()
/// let request = GetAuthMethodsRequest(token: accessToken, domain: "my-tenant.auth0.com")
/// let methods = try await useCase.execute(request: request)
///
/// // In tests with mock
/// let mockUseCase = MockGetAuthMethodsUseCase()
/// mockUseCase.stubbedResult = [mockAuthMethod]
/// let methods = try await mockUseCase.execute(request: request)
/// ```
///
/// - Note: Implementations should handle errors appropriately, including network failures,
///   invalid tokens, and malformed responses.
protocol GetAuthMethodsUseCaseable {
    /// The URLSession instance used for making HTTP network requests.
    ///
    /// Provides access to the underlying network session for:
    /// - Making API calls to Auth0 endpoints
    /// - Customizing request behavior (timeouts, caching, etc.)
    /// - Enabling network mocking in tests by injecting custom sessions
    ///
    /// **Default**: Most implementations use `URLSession.shared`
    ///
    /// **Testing**: Inject a custom `URLSession` with mocked responses for unit testing
    ///
    /// - Note: The Auth0 SDK uses this session internally for all network operations.
    var session: URLSession { get }

    /// Executes the API request to retrieve the user's enrolled authentication methods.
    ///
    /// This method performs an authenticated call to the Auth0 MyAccount API to fetch
    /// the complete list of authentication methods that the user has enrolled. The operation
    /// is asynchronous and may take several seconds depending on network conditions.
    ///
    /// ## Request Flow
    ///
    /// 1. **Validation**: Validates the token and domain from the request
    /// 2. **API Call**: Makes HTTP GET request to MyAccount authentication methods endpoint
    /// 3. **Response**: Receives JSON array of authentication method objects
    /// 4. **Decoding**: Parses JSON into `AuthenticationMethod` model objects
    /// 5. **Return**: Returns the array of enrolled methods
    ///
    /// ## Response Data
    ///
    /// Each `AuthenticationMethod` in the returned array contains:
    /// - `id`: Unique identifier for this enrolled method
    /// - `type`: Method type (totp, push-notification, email, phone, recovery-code)
    /// - `confirmed`: Whether enrollment is complete and verified
    /// - `name`: User-friendly name or identifier (email, phone, device name)
    /// - `created_at`: When the method was enrolled
    /// - `last_auth`: When the method was last used for authentication
    ///
    /// ## Error Scenarios
    ///
    /// This method may throw errors in the following situations:
    ///
    /// ### Network Errors
    /// - No internet connection
    /// - Request timeout
    /// - DNS resolution failure
    ///
    /// ### Authentication Errors
    /// - Invalid or expired access token (401 Unauthorized)
    /// - Insufficient token scopes (403 Forbidden)
    /// - Token missing required `read:me:authentication_methods` scope
    ///
    /// ### API Errors
    /// - Auth0 service unavailable (503 Service Unavailable)
    /// - Rate limit exceeded (429 Too Many Requests)
    /// - Invalid domain configuration (404 Not Found)
    ///
    /// ### Data Errors
    /// - Malformed JSON response
    /// - Unexpected response structure
    /// - Decoding failures
    ///
    /// ## Parameters
    ///
    /// - Parameter request: A `GetAuthMethodsRequest` containing the authenticated access token
    ///   and Auth0 tenant domain needed to make the API call
    ///
    /// ## Returns
    ///
    /// An array of `AuthenticationMethod` objects representing all methods the user has enrolled.
    /// - Empty array if user has no enrolled methods
    /// - Non-empty array with details about each enrolled method
    /// - Methods may include both confirmed (fully enrolled) and unconfirmed (pending) statuses
    ///
    /// ## Throws
    ///
    /// Propagates errors from the Auth0 SDK, which may include:
    /// - Network-related errors (URLError)
    /// - Authentication errors (Auth0 API errors)
    /// - Decoding errors (DecodingError)
    ///
    /// ## Usage Example
    ///
    /// ```swift
    /// do {
    ///     let request = GetAuthMethodsRequest(
    ///         token: apiCredentials.accessToken,
    ///         domain: "my-tenant.auth0.com"
    ///     )
    ///     let authMethods = try await execute(request: request)
    ///
    ///     // Filter to confirmed methods only
    ///     let confirmedMethods = authMethods.filter { $0.confirmed }
    ///     print("User has \(confirmedMethods.count) enrolled methods")
    /// } catch {
    ///     print("Failed to fetch methods: \(error)")
    /// }
    /// ```
    ///
    /// - Important: This method must be called with a valid, non-expired access token that includes
    ///   the `read:me:authentication_methods` scope, otherwise it will fail with an authorization error.
    func execute(request: GetAuthMethodsRequest) async throws -> [AuthenticationMethod]
}

/// Concrete implementation of the ``GetAuthMethodsUseCaseable`` protocol.
///
/// `GetAuthMethodsUseCase` is the production implementation that communicates with Auth0's
/// MyAccount API to retrieve a user's enrolled authentication methods. It leverages the
/// official `Auth0.swift` SDK to handle API communication, authentication, and response parsing.
///
/// ## Architecture Role
///
/// - **Domain Layer**: Part of the business logic layer in Clean Architecture
/// - **Production Implementation**: The concrete class used in production (not a mock or test double)
/// - **SDK Wrapper**: Wraps Auth0 SDK calls with a use case interface for testability
/// - **Stateless**: Each execution is independent; no state is maintained between calls
///
/// ## Implementation Details
///
/// This implementation uses the Auth0 SDK's MyAccount API client to:
/// 1. Create an authenticated API client using the provided token and domain
/// 2. Access the authentication methods endpoint
/// 3. Execute the HTTP GET request to retrieve enrolled methods
/// 4. Parse the JSON response into `AuthenticationMethod` model objects
/// 5. Return the array of enrolled methods or propagate errors
///
/// ## Thread Safety
///
/// This struct is thread-safe and can be used concurrently:
/// - No mutable state (URLSession is immutable after initialization)
/// - All methods use async/await for proper concurrency handling
/// - Can be safely shared across multiple tasks
///
/// ## Testing Strategy
///
/// For unit testing, inject a custom `URLSession` with mocked responses:
/// ```swift
/// let mockSession = URLSession.mockWithResponse(data: mockJSON)
/// let useCase = GetAuthMethodsUseCase(session: mockSession)
/// let methods = try await useCase.execute(request: mockRequest)
/// // Assert on methods
/// ```
///
/// Alternatively, use a mock implementation of `GetAuthMethodsUseCaseable` protocol.
///
/// ## Error Handling
///
/// This implementation propagates errors from the Auth0 SDK, which may include:
/// - `MyAccountError`: API-level errors (401 Unauthorized, 403 Forbidden, 500 Server Error)
/// - `URLError`: Network-level errors (timeout, no connection, DNS failure)
/// - `DecodingError`: JSON parsing errors from malformed responses
///
/// ## Usage Example
///
/// ```swift
/// let useCase = GetAuthMethodsUseCase()
/// let request = GetAuthMethodsRequest(
///     token: "eyJhbGciOiJSUzI1NiIsInR5cCI6IkpXVCJ9...",
///     domain: "my-tenant.auth0.com"
/// )
///
/// do {
///     let authMethods = try await useCase.execute(request: request)
///     print("User has \(authMethods.count) enrolled methods")
/// } catch {
///     print("Failed to fetch methods: \(error)")
/// }
/// ```
///
/// - Note: This struct is lightweight and can be instantiated per-use or reused across multiple calls.
struct GetAuthMethodsUseCase: GetAuthMethodsUseCaseable {
    /// The URLSession instance used for making HTTP network requests to Auth0 APIs.
    ///
    /// This session is passed to the Auth0 SDK for all network operations related to
    /// fetching authentication methods. The session configuration determines:
    /// - Timeout intervals for requests
    /// - Caching behavior for responses
    /// - Cookie handling policies
    /// - TLS/SSL certificate validation
    ///
    /// ## Default Value
    ///
    /// Uses `URLSession.shared` by default, which provides:
    /// - Reasonable default timeout values
    /// - System-managed connection pooling
    /// - Disk-based caching
    /// - Standard security settings
    ///
    /// ## Custom Sessions
    ///
    /// You can inject custom sessions for specific needs:
    ///
    /// ### Testing
    /// ```swift
    /// let mockSession = URLSession.mock(with: stubbedData)
    /// let useCase = GetAuthMethodsUseCase(session: mockSession)
    /// ```
    ///
    /// ### Custom Timeouts
    /// ```swift
    /// let config = URLSessionConfiguration.default
    /// config.timeoutIntervalForRequest = 30
    /// let session = URLSession(configuration: config)
    /// let useCase = GetAuthMethodsUseCase(session: session)
    /// ```
    ///
    /// ### Certificate Pinning
    /// ```swift
    /// let session = URLSession(configuration: .default, delegate: certificatePinner, delegateQueue: nil)
    /// let useCase = GetAuthMethodsUseCase(session: session)
    /// ```
    ///
    /// - Note: The session is stored as a computed property requirement from the protocol,
    ///   allowing test code to access the session for verification purposes.
    var session: URLSession

    /// Initializes a new use case instance with an optional custom URLSession.
    ///
    /// Creates a new instance of the use case, optionally allowing injection of a custom
    /// URLSession for testing, custom configuration, or certificate pinning scenarios.
    ///
    /// ## Default Initialization
    ///
    /// When called without parameters, uses the shared URLSession:
    /// ```swift
    /// let useCase = GetAuthMethodsUseCase()
    /// // Equivalent to: GetAuthMethodsUseCase(session: URLSession.shared)
    /// ```
    ///
    /// ## Custom Session Injection
    ///
    /// For testing or custom configuration, pass a configured session:
    /// ```swift
    /// let customSession = URLSession(configuration: .ephemeral)
    /// let useCase = GetAuthMethodsUseCase(session: customSession)
    /// ```
    ///
    /// ## Use Cases
    ///
    /// ### Production Use
    /// ```swift
    /// // Simple default initialization
    /// let useCase = GetAuthMethodsUseCase()
    /// ```
    ///
    /// ### Unit Testing
    /// ```swift
    /// // Inject mock session with stubbed responses
    /// let mockSession = URLSessionMock(stubbedData: mockJSON)
    /// let useCase = GetAuthMethodsUseCase(session: mockSession)
    /// ```
    ///
    /// ### Custom Configuration
    /// ```swift
    /// // Use ephemeral session (no disk caching)
    /// let config = URLSessionConfiguration.ephemeral
    /// let session = URLSession(configuration: config)
    /// let useCase = GetAuthMethodsUseCase(session: session)
    /// ```
    ///
    /// ### Certificate Pinning
    /// ```swift
    /// // Use session with custom delegate for certificate validation
    /// let pinnedSession = URLSession(
    ///     configuration: .default,
    ///     delegate: CertificatePinner(),
    ///     delegateQueue: nil
    /// )
    /// let useCase = GetAuthMethodsUseCase(session: pinnedSession)
    /// ```
    ///
    /// - Parameter session: The URLSession to use for network requests. Defaults to `URLSession.shared`
    ///   if not specified, which is appropriate for most production scenarios.
    ///
    /// - Note: This initializer is lightweight and can be called frequently without performance concerns.
    init(session: URLSession = URLSession.shared) {
        self.session = session
    }

    /// Executes the API request to retrieve the user's enrolled authentication methods.
    ///
    /// This method performs the complete flow of fetching authentication methods from Auth0:
    /// 1. Creates an authenticated MyAccount API client using the token and domain
    /// 2. Accesses the authentication methods endpoint
    /// 3. Executes the HTTP GET request
    /// 4. Parses the JSON response into strongly-typed Swift models
    /// 5. Returns the array of enrolled authentication methods
    ///
    /// ## Implementation Flow
    ///
    /// The method uses the Auth0 SDK's fluent API to build and execute the request:
    /// ```
    /// Auth0.myAccount()           → Creates MyAccount API client
    ///   .authenticationMethods    → Accesses the auth methods endpoint
    ///   .getAuthenticationMethods() → Builds the GET request
    ///   .start()                  → Executes the request asynchronously
    /// ```
    ///
    /// ## API Endpoint
    ///
    /// Makes a GET request to:
    /// ```
    /// https://{domain}/mfa/authenticators
    /// ```
    ///
    /// With headers:
    /// ```
    /// Authorization: Bearer {token}
    /// Content-Type: application/json
    /// ```
    ///
    /// ## Response Format
    ///
    /// The API returns a JSON array of authentication method objects:
    /// ```json
    /// [
    ///   {
    ///     "id": "auth_method_123",
    ///     "type": "totp",
    ///     "confirmed": true,
    ///     "name": "Google Authenticator",
    ///     "created_at": "2024-01-15T10:30:00.000Z",
    ///     "last_auth": "2024-01-20T14:22:00.000Z"
    ///   }
    /// ]
    /// ```
    ///
    /// ## Async Execution
    ///
    /// This method uses Swift's async/await pattern:
    /// - Non-blocking: Suspends execution without blocking the thread
    /// - Cancellation: Respects Task cancellation
    /// - Error propagation: Uses `throws` for error handling
    ///
    /// ## Error Scenarios
    ///
    /// See protocol documentation for comprehensive error scenarios. Common errors include:
    /// - **401 Unauthorized**: Invalid or expired token
    /// - **403 Forbidden**: Token lacks required scopes
    /// - **Network errors**: Timeout, no connection, DNS failure
    /// - **Decoding errors**: Unexpected response format
    ///
    /// - Parameter request: The ``GetAuthMethodsRequest`` containing the authenticated access token
    ///   and Auth0 tenant domain needed to make the API call
    ///
    /// - Returns: An array of ``AuthenticationMethod`` objects representing all methods the user
    ///   has enrolled. Returns an empty array if the user has no enrolled methods.
    ///
    /// - Throws: Errors from the Auth0 SDK, including network errors, API errors, and decoding errors
    ///
    /// - Note: The Auth0 SDK automatically handles JSON parsing and model mapping, returning
    ///   strongly-typed Swift objects rather than raw JSON.
    func execute(request: GetAuthMethodsRequest) async throws -> [AuthenticationMethod] {
        // Create an authenticated MyAccount API client with the provided credentials
        // The token authorizes the request, and the domain identifies the Auth0 tenant
        try await Auth0.myAccount(token: request.token, domain: request.domain, session: session)
            // Access the authentication methods API endpoint
            .authenticationMethods
            // Build the GET request to retrieve all enrolled authentication methods
            .getAuthenticationMethods()
            // Execute the request asynchronously and parse the response
            // Returns [AuthenticationMethod] or throws on error
            .start()
    }
}
