import Auth0
import SwiftUI
import Foundation

/// Comprehensive error enumeration for Auth0 UI Components SDK.
///
/// Auth0UIComponentError handles all possible error scenarios that can occur
/// during authentication, MFA enrollment, token refresh, and API calls.
/// Each case includes a user-friendly message and optional underlying cause error.
///
/// The enum provides two main functionalities:
/// 1. Error categorization for different failure scenarios
/// 2. Conversion to ErrorScreenViewModel for displaying errors to users
enum Auth0UIComponentError {
    // MARK: - Web Authentication Errors
    
    /// ID token validation failed during authentication.
    /// This indicates the token returned from Auth0 failed cryptographic validation.
    ///
    /// - Parameters:
    ///   - message: User-friendly error message
    ///   - cause: Underlying error that caused validation to fail
    case idTokenValidationFailed(message: String,
                                 cause: Error? = nil)
    
    /// No bundle identifier found in the app.
    /// This is required for associated domains and deep linking configuration.
    ///
    /// - Parameters:
    ///   - message: User-friendly error message
    ///   - cause: Underlying error
    case noBundleIdentifier(message: String,
                            cause: Error? = nil)
    
    /// User cancelled the authentication flow.
    /// This typically occurs when user dismisses the Universal Login or WebAuth screen.
    ///
    /// - Parameters:
    ///   - message: User-friendly error message (defaults to "Something went wrong")
    ///   - cause: Underlying error if applicable
    case userCancelled(message: String = "Something went wrong",
                       cause: Error? = nil)
    
    /// A Web Auth transaction is already in progress.
    /// Cannot start a new authentication flow until the current one completes.
    ///
    /// - Parameters:
    ///   - message: User-friendly error message
    ///   - cause: Underlying error
    case transactionActiveAlready(message: String, cause: Error? = nil)

    /// PKCE (Proof Key for Public Clients) is not allowed by server configuration.
    /// This indicates OAuth configuration mismatch.
    ///
    /// - Parameters:
    ///   - message: User-friendly error message
    ///   - cause: Underlying error
    case pkceNotAllowed(message: String, cause: Error? = nil)

    /// The invitation URL is invalid or malformed.
    /// Occurs when using organization invitations with invalid URL format.
    ///
    /// - Parameters:
    ///   - message: User-friendly error message
    ///   - cause: String description of the issue
    case invalidInvitationURL(message: String, cause: String? = nil)

    /// No authorization code was returned from Auth0.
    /// This indicates a failure in the OAuth authorization code flow.
    ///
    /// - Parameters:
    ///   - message: User-friendly error message
    ///   - cause: String description of the issue
    case noAuthorizationCode(message: String, cause: String? = nil)

    /// Access denied by the authorization server.
    /// User may lack required permissions or the application is unauthorized.
    ///
    /// - Parameters:
    ///   - message: User-friendly error message (defaults to "Access denied")
    ///   - cause: Underlying error
    case accessDenied(message: String = "Access denied",
                      cause: Error? = nil)

    // MARK: - Multi-Factor Authentication (MFA) Errors
    
    /// Multi-factor authentication is required to complete the action.
    /// User must complete MFA challenge to proceed (step-up flow).
    ///
    /// - Parameters:
    ///   - message: User-friendly error message (defaults to "Multi-factor authentication required")
    ///   - cause: Underlying authentication error
    case mfaRequired(message: String = "Multi-factor authentication required",
                     cause: Error? = nil)

    /// MFA enrollment is required to complete the action.
    /// User must enroll in at least one MFA method before proceeding.
    ///
    /// - Parameters:
    ///   - message: User-friendly error message (defaults to "MFA enrollment required")
    ///   - cause: Underlying authentication error
    case mfaEnrollRequired(message: String = "MFA enrollment required",
                           cause: Error? = nil)

    /// The MFA code entered by user is invalid or has expired.
    /// User should verify the code and try again.
    ///
    /// - Parameters:
    ///   - message: User-friendly error message (defaults to "Invalid or expired MFA code")
    ///   - cause: Underlying error
    case invalidMfaCode(message: String = "Invalid or expired MFA code",
                        cause: Error? = nil)

    /// The MFA token is invalid or has expired.
    /// MFA token is used internally for MFA verification process.
    ///
    /// - Parameters:
    ///   - message: User-friendly error message (defaults to "Invalid or expired MFA token")
    ///   - cause: Underlying error
    case invalidMfaToken(message: String = "Invalid or expired MFA token",
                         cause: Error? = nil)

    // MARK: - Token & Session Errors
    
    /// Refresh token is invalid or has expired.
    /// User needs to login again to obtain a new refresh token.
    ///
    /// - Parameters:
    ///   - message: User-friendly error message (defaults to "Invalid or expired refresh token")
    ///   - cause: Underlying error
    case refreshTokenInvalid(message: String = "Invalid or expired refresh token",
                             cause: Error? = nil)

    /// Refresh token has been deleted from the server.
    /// This typically occurs when user or administrator revoked the token.
    ///
    /// - Parameters:
    ///   - message: User-friendly error message (defaults to "Refresh token no longer exists")
    ///   - cause: Underlying error
    case refreshTokenDeleted(message: String = "Refresh token no longer exists",
                             cause: Error? = nil)

    /// User session has expired.
    /// User must login again to establish a new session.
    ///
    /// - Parameters:
    ///   - message: User-friendly error message (defaults to "Session has expired, please login again")
    ///   - cause: Underlying error
    case sessionExpired(message: String = "Session has expired, please login again",
                        cause: Error? = nil)

    // MARK: - Rate Limiting & Security Errors
    
    /// Too many failed login attempts.
    /// Account is temporarily locked for security reasons.
    ///
    /// - Parameters:
    ///   - message: User-friendly error message (defaults to security lock message)
    ///   - cause: Underlying error
    case tooManyAttempts(message: String = "Too many login attempts, account temporarily blocked",
                         cause: Error? = nil)

    // MARK: - Network Errors
    
    /// Network connection failed.
    /// This occurs when device cannot reach the Auth0 server.
    ///
    /// - Parameters:
    ///   - message: User-friendly error message (defaults to "Network connection failed")
    ///   - cause: Underlying network error
    case networkError(message: String = "Network connection failed",
                      cause: Error? = nil)

    /// Request timed out.
    /// The server did not respond within the expected time frame.
    ///
    /// - Parameters:
    ///   - message: User-friendly error message (defaults to "Request timed out")
    ///   - cause: Underlying error
    case timeout(message: String = "Request timed out",
                 cause: Error? = nil)

    // MARK: - Validation Errors
    
    /// Request validation failed.
    /// One or more fields in the request contain invalid data.
    ///
    /// - Parameters:
    ///   - message: User-friendly error message (defaults to "Validation failed")
    ///   - cause: Underlying error
    ///   - errors: Array of field-specific validation errors with details
    case validationError(
        message: String = "Validation failed",
        cause: Error? = nil,
        errors: [FieldError] = []
    )

    // MARK: - Server Errors
    
    /// Server error occurred (5xx status code).
    /// Auth0 server encountered an unexpected error while processing the request.
    ///
    /// - Parameters:
    ///   - message: User-friendly error message (defaults to "Server error occurred")
    ///   - statusCode: HTTP status code returned by server
    ///   - cause: Underlying error
    case serverError(message: String = "Server error occurred",
                     statusCode: Int,
                     cause: Error? = nil)

    // MARK: - Generic/Unknown Errors
    
    /// An unknown or unclassified error occurred.
    /// This is a catch-all for errors that don't fit into other categories.
    ///
    /// - Parameters:
    ///   - message: User-friendly error message (defaults to "An unknown error occurred")
    ///   - cause: Underlying error
    case unknown(message: String = "An unknown error occurred",
                 cause: Error? = nil)
}

// MARK: - ErrorScreenViewModel Conversion

extension Auth0UIComponentError {
    /// Converts Auth0UIComponentError to ErrorScreenViewModel for UI display.
    ///
    /// This function creates user-friendly error screens with appropriate titles,
    /// subtitles, and action buttons. Different error types display different messages
    /// and actions to guide users on how to resolve the issue.
    ///
    /// - Parameter completion: Closure executed when user taps "Try again" button
    /// - Returns: ErrorScreenViewModel configured for the error, or nil if no UI display needed
    ///
    /// - Note: Returns nil for .mfaRequired error as it triggers Universal Login flow instead
    func errorViewModel(completion: @escaping () -> Void) -> ErrorScreenViewModel? {
        switch self {
        // MARK: Network Error Display
        
        case .networkError:
            // Format subtitle with gray color
            var subTitleText = AttributedString("Please check your internet connection")
            subTitleText.foregroundColor = Color("737373", bundle: ResourceBundle.default)
            
            return ErrorScreenViewModel(
                title: "Connection problem",
                subTitle: subTitleText,
                buttonTitle: "Try again",
                textTap: {},
                buttonClick: {
                    completion()
                }
            )
        
        // MARK: Invalid MFA Code Display
        
        case .invalidMfaCode:
            // Provide guidance on why code is invalid and suggest retry
            var subTitleText = AttributedString("The code you entered is incorrect or has expired. Please try again.")
            subTitleText.foregroundColor = Color("737373", bundle: ResourceBundle.default)
            
            return ErrorScreenViewModel(
                title: "Invalid verification code",
                subTitle: subTitleText,
                buttonTitle: "Try again",
                textTap: {},
                buttonClick: {
                    completion()
                }
            )
        
        // MARK: Session Expired Display
        
        case .sessionExpired:
            // Inform user session expired and they need to login again
            var subTitleText = AttributedString("Your session has expired. Please login again to continue.")
            subTitleText.foregroundColor = Color("737373", bundle: ResourceBundle.default)
            
            return ErrorScreenViewModel(
                title: "Session expired",
                subTitle: subTitleText,
                buttonTitle: "Try again",
                textTap: {},
                buttonClick: {
                    completion()
                }
            )
        
        // MARK: Too Many Attempts Display
        
        case .tooManyAttempts:
            // Inform user about account temporary lock due to security
            var subTitleText = AttributedString("Your account has been temporarily blocked due to too many failed attempts. Please try again later.")
            subTitleText.foregroundColor = Color("737373", bundle: ResourceBundle.default)
            
            return ErrorScreenViewModel(
                title: "Too many attempts",
                subTitle: "Your account has been temporarily blocked due to too many failed attempts. Please try again later.",
                buttonTitle: "Try again",
                textTap: {},
                buttonClick: {
                    completion()
                }
            )
        
        // MARK: MFA Required - No UI Display
        
        case .mfaRequired:
            // MFA required error is handled by initiating Universal Login flow
            // No error screen is displayed for this case
            return nil
        
        // MARK: Generic Error Display for All Other Cases
        
        case .accessDenied(let message, _),
             .mfaEnrollRequired(let message, _),
             .invalidMfaToken(let message, _),
             .refreshTokenInvalid(let message, _),
             .refreshTokenDeleted(let message, _),
             .timeout(let message, _),
             .validationError(let message, _, _),
             .serverError(let message, _, _),
             .unknown(let message, _),
             .invalidInvitationURL(let message, _),
             .noBundleIdentifier(let message, _),
             .pkceNotAllowed(let message, _),
             .noAuthorizationCode(let message, _),
             .transactionActiveAlready(let message, _),
             .idTokenValidationFailed(let message, _),
             .userCancelled(let message, _):
            
            // Create formatted subtitle with contact us link
            var full = AttributedString("We are unable to process your request. Please try again in a few minutes. If this problem persists, please contact us.")
            full.foregroundColor = Color("737373", bundle: ResourceBundle.default)
            
            // Underline the "contact us" text to indicate it's clickable
            if let range = full.range(of: "contact us.") {
                full[range].underlineStyle = .single
            }
            
            return ErrorScreenViewModel(
                title: message,
                subTitle: full,
                buttonTitle: "Try again",
                textTap: {
                    // Open Auth0 support contact page when user taps "contact us"
                    if let url = URL(string: "https://auth0.com/contact-us") {
                        #if os(macOS)
                        NSWorkspace.shared.open(url)
                        #else
                        UIApplication.shared.open(url)
                        #endif
                    }
                },
                buttonClick: {
                    // Execute retry callback when user taps "Try again"
                    completion()
                }
            )
        }
    }
    
    // MARK: - Error Conversion Helpers
    
    /// Converts WebAuthError to Auth0UIComponentError.
    ///
    /// Maps Auth0.swift WebAuthError cases to corresponding Auth0UIComponentError cases
    /// for consistent error handling throughout the SDK.
    ///
    /// - Parameter error: WebAuthError from Auth0.swift library
    /// - Returns: Corresponding Auth0UIComponentError
    static func handleWebAuthError(error: WebAuthError) -> Auth0UIComponentError {
        // Handle user cancellation separately
        if error == WebAuthError.userCancelled {
            return .userCancelled()
        }
        
        // Convert all other WebAuthErrors to unknown with original message and cause
        return .unknown(message: error.message, cause: error.cause)
    }

    /// Converts CredentialsManagerError to Auth0UIComponentError.
    ///
    /// Analyzes CredentialsManagerError and its underlying AuthenticationError
    /// to determine the specific error type and create appropriate error message.
    ///
    /// This handles:
    /// - MFA required scenarios (triggers step-up flow)
    /// - Network errors
    /// - MFA enrollment requirements
    /// - Invalid MFA tokens/codes
    /// - Access denied
    /// - Session expiration
    /// - Refresh token issues
    /// - Rate limiting
    ///
    /// - Parameter error: CredentialsManagerError from Auth0.swift
    /// - Returns: Categorized Auth0UIComponentError with appropriate message
    static func handleCredentialsManagerError(error: CredentialsManagerError) -> Auth0UIComponentError {
        // Extract underlying AuthenticationError for detailed analysis
        if let authenticationError = error.cause as? AuthenticationError {
            // MARK: Check MFA Required
            
            if authenticationError.isMultifactorRequired {
                return .mfaRequired(
                    message: "Multi-factor authentication is required",
                    cause: authenticationError.cause
                )
            }
            
            // MARK: Check Network Error
            
            if authenticationError.isNetworkError {
                return .networkError(
                    message: "Network connection failed",
                    cause: authenticationError
                )
            }
            
            // MARK: Check MFA Enrollment Required
            
            if authenticationError.isMultifactorEnrollRequired {
                return .mfaEnrollRequired(
                    message: "MFA enrollment is required to continue",
                    cause: authenticationError
                )
            }
            
            // MARK: Check Invalid MFA Token
            
            if authenticationError.isMultifactorTokenInvalid {
                return .invalidMfaToken(
                    message: "The MFA token is invalid or has expired",
                    cause: authenticationError
                )
            }
            
            // MARK: Check Invalid MFA Code
            
            if authenticationError.isMultifactorCodeInvalid {
                return .invalidMfaCode(
                    message: "The MFA code is invalid or has expired",
                    cause: authenticationError
                )
            }
            
            // MARK: Check Access Denied
            
            if authenticationError.isAccessDenied {
                return .accessDenied(
                    message: "Access denied by authorization server",
                    cause: authenticationError
                )
            }
            
            // MARK: Check Login Required (Session Expired)
            
            if authenticationError.isLoginRequired {
                return .sessionExpired(
                    message: "Session expired, please login again",
                    cause: authenticationError
                )
            }
            
            // MARK: Check Invalid Refresh Token
            
            if authenticationError.isInvalidRefreshToken {
                return .refreshTokenInvalid(
                    message: "Refresh token is invalid or expired",
                    cause: authenticationError
                )
            }
            
            // MARK: Check Deleted Refresh Token
            
            if authenticationError.isRefreshTokenDeleted {
                return .refreshTokenDeleted(
                    message: "User account no longer exists",
                    cause: authenticationError
                )
            }
            
            // MARK: Check Too Many Attempts
            
            if authenticationError.isTooManyAttempts {
                return .tooManyAttempts(
                    message: "Too many failed attempts, please try again later",
                    cause: authenticationError
                )
            }
            
            // MARK: Generic Server Error
            
            return .serverError(
                message: authenticationError.message,
                statusCode: authenticationError.statusCode,
                cause: authenticationError
            )
        } else {
            // No AuthenticationError found, return generic unknown error
            return .unknown(
                message: error.localizedDescription,
                cause: error.cause
            )
        }
    }
    
    /// Converts MyAccountError to Auth0UIComponentError.
    ///
    /// Analyzes MyAccountError to determine the specific error type and create
    /// appropriate error message for operations like fetching factors or auth methods.
    ///
    /// This handles:
    /// - Network errors
    /// - Validation errors with field-level details
    /// - Server errors (5xx status codes)
    /// - Generic API errors
    ///
    /// - Parameter error: MyAccountError from SDK's API layer
    /// - Returns: Categorized Auth0UIComponentError with appropriate message
    static func handleMyAccountAuthError(error: MyAccountError) -> Auth0UIComponentError {
        // MARK: Check Network Error
        
        if error.isNetworkError {
            return .networkError(
                message: "Network connection failed",
                cause: error
            )
        }

        // MARK: Check Validation Errors
        
        if error.validationErrors?.isEmpty == false {
            // Convert API validation errors to FieldError objects
            return .validationError(
                message: error.detail,
                cause: error,
                errors: (error.validationErrors ?? []).map {
                    FieldError(
                        field: $0.field,
                        detail: $0.detail,
                        pointer: $0.pointer,
                        source: $0.source
                    )
                }
            )
        }

        // MARK: Check Server Error
        
        if error.statusCode >= 500 {
            return .serverError(
                message: "Server error, please try again",
                statusCode: error.statusCode,
                cause: error
            )
        }

        // MARK: Generic Unknown Error
        
        return .unknown(
            message: error.detail,
            cause: error
        )
    }
}

// MARK: - FieldError Model

/// Represents a validation error for a specific field.
///
/// Used in .validationError case to provide field-level validation feedback
/// to users so they can correct specific issues in forms.
struct FieldError {
    /// The name of the field that failed validation
    let field: String?
    
    /// Detailed message about what validation failed
    let detail: String
    
    /// JSON pointer to the field in the request (e.g., "/email")
    let pointer: String?
    
    /// Source of the validation error (e.g., "body", "query")
    let source: String?
}
