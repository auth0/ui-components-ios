import Auth0
import Foundation

/// A structured request object containing credentials required to fetch available MFA factors.
///
/// `GetFactorsRequest` encapsulates the data needed to query Auth0's MyAccount API for the list
/// of authentication factors (TOTP, Push, Email, SMS, Recovery Codes) that are enabled for the
/// user's account. Uses the Parameter Object pattern for clean API design.
///
/// ## Required OAuth Scopes
///
/// - `openid`: OpenID Connect authentication
/// - `read:me:factors`: Permission to read available MFA factors
///
/// ## Usage Example
///
/// ```swift
/// let request = GetFactorsRequest(
///     token: "eyJhbGciOiJSUzI1NiIs...",
///     domain: "my-tenant.auth0.com"
/// )
/// let factors = try await useCase.execute(request: request)
/// ```
struct GetFactorsRequest {
    /// OAuth 2.0 access token with `read:me:factors` scope.
    ///
    /// Must be a valid JWT token obtained through authentication or token refresh.
    ///
    /// - Important: Never log or expose this token.
    let token: String

    /// Auth0 tenant domain without protocol.
    ///
    /// **Examples**: `"my-tenant.auth0.com"`, `"my-tenant.eu.auth0.com"`
    let domain: String
}

/// Defines the contract for fetching available MFA factors from Auth0.
///
/// `GetFactorsUseCaseable` abstracts the logic for retrieving the list of authentication factors
/// that are enabled for the user's account. This protocol follows the Use Case pattern from
/// Clean Architecture, enabling testability through dependency inversion.
///
/// ## What Are Factors?
///
/// Factors are the MFA methods available for enrollment:
/// - **TOTP**: Authenticator apps (Google Authenticator, Authy)
/// - **Push**: Push notifications via Guardian app
/// - **Email**: Email-based one-time passwords
/// - **SMS**: SMS-based one-time passwords
/// - **Recovery Code**: Backup codes for emergency access
///
/// ## Usage Example
///
/// ```swift
/// let useCase: GetFactorsUseCaseable = GetFactorsUseCase()
/// let request = GetFactorsRequest(token: accessToken, domain: "my-tenant.auth0.com")
/// let factors = try await useCase.execute(request: request)
/// print("Available factors: \(factors.map { $0.type })")
/// ```
protocol GetFactorsUseCaseable {
    /// URLSession used for making HTTP network requests.
    ///
    /// Enables custom session injection for testing or custom configuration.
    var session: URLSession { get }

    /// Executes the API request to retrieve available MFA factors.
    ///
    /// Fetches the list of authentication factors that are enabled for the user's account
    /// from Auth0's MyAccount API. This determines which enrollment options to display in the UI.
    ///
    /// ## Returns
    ///
    /// An array of `Factor` objects, each containing:
    /// - `type`: Factor type (totp, push-notification, email, phone, recovery-code)
    /// - `enabled`: Whether the factor is available for enrollment
    ///
    /// ## Throws
    ///
    /// - **Network errors**: Timeout, no connection, DNS failure
    /// - **Auth errors**: Invalid token (401), insufficient scopes (403)
    /// - **API errors**: Server error (500), rate limit (429)
    /// - **Decoding errors**: Malformed JSON response
    ///
    /// - Parameter request: The `GetFactorsRequest` containing access token and domain
    /// - Returns: Array of `Factor` objects representing available MFA methods
    func execute(request: GetFactorsRequest) async throws -> [Factor]
}

/// Production implementation that fetches available MFA factors from Auth0.
///
/// `GetFactorsUseCase` is the concrete implementation that communicates with Auth0's MyAccount API
/// to retrieve the list of authentication factors enabled for the user's account. It wraps the
/// Auth0 SDK's factors API with a use case interface for testability.
///
/// ## API Endpoint
///
/// Makes a GET request to: `https://{domain}/mfa/factors`
///
/// ## Thread Safety
///
/// Thread-safe and can be used concurrently:
/// - No mutable state
/// - All methods use async/await
///
/// ## Usage Example
///
/// ```swift
/// let useCase = GetFactorsUseCase()
/// let request = GetFactorsRequest(token: accessToken, domain: "my-tenant.auth0.com")
///
/// do {
///     let factors = try await useCase.execute(request: request)
///     let enabledFactors = factors.filter { $0.enabled }
///     print("User can enroll in: \(enabledFactors.map { $0.type })")
/// } catch {
///     print("Failed to fetch factors: \(error)")
/// }
/// ```
struct GetFactorsUseCase: GetFactorsUseCaseable {
    /// URLSession instance for making HTTP network requests to Auth0 APIs.
    ///
    /// Determines timeout intervals, caching behavior, and security settings.
    ///
    /// **Default**: `URLSession.shared`
    ///
    /// **Testing**: Inject custom session with mocked responses:
    /// ```swift
    /// let mockSession = URLSession.mock(with: mockData)
    /// let useCase = GetFactorsUseCase(session: mockSession)
    /// ```
    var session: URLSession

    /// Initializes the use case with optional custom URLSession.
    ///
    /// **Default**: Uses `URLSession.shared` for production use
    ///
    /// **Testing**: Inject mock session for unit tests:
    /// ```swift
    /// let useCase = GetFactorsUseCase(session: mockSession)
    /// ```
    ///
    /// - Parameter session: URLSession for network requests. Defaults to `URLSession.shared`.
    init(session: URLSession = URLSession.shared) {
        self.session = session
    }

    /// Executes the API request to retrieve available MFA factors.
    ///
    /// Fetches the list of authentication factors from Auth0's MyAccount API using the Auth0 SDK.
    /// The response indicates which MFA methods are available for enrollment.
    ///
    /// ## Implementation Flow
    ///
    /// ```
    /// Auth0.myAccount()        → Creates MyAccount API client
    ///   .authenticationMethods → Accesses auth methods endpoint
    ///   .getFactors()          → Builds GET request for factors
    ///   .start()               → Executes request asynchronously
    /// ```
    ///
    /// ## Response Format
    ///
    /// Returns JSON array of factor objects:
    /// ```json
    /// [
    ///   { "type": "totp", "enabled": true },
    ///   { "type": "email", "enabled": true },
    ///   { "type": "phone", "enabled": false }
    /// ]
    /// ```
    ///
    /// - Parameter request: The `GetFactorsRequest` containing access token and domain
    /// - Returns: Array of `Factor` objects representing available MFA methods
    /// - Throws: Auth0 SDK errors including network, authentication, and decoding errors
    func execute(request: GetFactorsRequest) async throws -> [Factor] {
        // Create authenticated MyAccount API client with provided credentials
        try await Auth0.myAccount(token: request.token, domain: request.domain, session: session)
            // Access the authentication methods API endpoint
            .authenticationMethods
            // Build GET request to retrieve available factors
            .getFactors()
            // Execute request asynchronously and parse response
            .start()
    }
}
