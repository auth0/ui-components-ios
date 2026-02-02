import Auth0
import SwiftUI
import Foundation

/// Enum representing various error types that can occur in Auth0 UI Components.
enum Auth0UIComponentError {
    case idTokenValidationFailed(message: String,
                                 cause: Error? = nil)
    case noBundleIdentifier(message: String,
                            cause: Error? = nil)
    case userCancelled(message: String = "Something went wrong",
                       cause: Error? = nil)
    case transactionActiveAlready(message: String,
                                  cause: Error? = nil)
    case pkceNotAllowed(message: String, cause: Error? = nil)
    case invalidInvitationURL(message: String,
                              cause: String? = nil)
    case noAuthorizationCode(message: String,
                             cause: String? = nil)
    case accessDenied(message: String = "Access denied",
                      cause: Error? = nil)
    case mfaRequired(message: String = "Multi-factor authentication required",
                     cause: Error? = nil)
    case mfaEnrollRequired(message: String = "MFA enrollment required",
                           cause: Error? = nil)
    case invalidMfaCode(message: String = "Invalid or expired MFA code",
                        cause: Error? = nil)
    case invalidMfaToken(message: String = "Invalid or expired MFA token",
                         cause: Error? = nil)
    case refreshTokenInvalid(message: String = "Invalid or expired refresh token",
                             cause: Error? = nil)
    case refreshTokenDeleted(message: String = "Refresh token no longer exists",
                             cause: Error? = nil)
    case sessionExpired(message: String = "Session has expired, please login again",
                        cause: Error? = nil)
    case tooManyAttempts(message: String = "Too many login attempts, account temporarily blocked",
                         cause: Error? = nil)
    case networkError(message: String = "Network connection failed",
                      cause: Error? = nil)
    case timeout(message: String = "Request timed out",
                 cause: Error? = nil)

    case validationError(
        message: String = "Validation failed",
        cause: Error? = nil,
        errors: [FieldError] = []
    )

    case serverError(message: String = "Server error occurred",
                     statusCode: Int,
                     cause: Error? = nil)

    case unknown(message: String = "An unknown error occurred",
                 cause: Error? = nil)
}

extension Auth0UIComponentError {
    func errorViewModel(completion: @escaping () -> Void) -> ErrorScreenViewModel? {
        switch self {
        case .networkError:
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
        case .invalidMfaCode:
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
        case .sessionExpired:
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
        case .tooManyAttempts:
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
        case .mfaRequired:
            return nil
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
            var full = AttributedString("We are unable to process your request. Please try again in a few minutes. If this problem persists, please contact us.")
            full.foregroundColor = Color("737373", bundle: ResourceBundle.default)
            
            if let range = full.range(of: "contact us.") {
                full[range].underlineStyle = .single
            }
            
            return ErrorScreenViewModel(
                title: message,
                subTitle: full,
                buttonTitle: "Try again",
                textTap: {
                    if let url = URL(string: "https://auth0.com/contact-us") {
                        #if os(macOS)
                        NSWorkspace.shared.open(url)
                        #else
                        UIApplication.shared.open(url)
                        #endif
                    }
                },
                buttonClick: {
                    completion()
                }
            )
        }
    }

    static func handleWebAuthError(error: WebAuthError) -> Auth0UIComponentError {
        if error == WebAuthError.userCancelled {
            return .userCancelled()
        }
        
        return .unknown(message: error.message, cause: error.cause)
    }

    static func handleCredentialsManagerError(error: CredentialsManagerError) -> Auth0UIComponentError {
        if let authenticationError = error.cause as? AuthenticationError {
            
            if authenticationError.isMultifactorRequired {
                return .mfaRequired(
                    message: "Multi-factor authentication is required",
                    cause: authenticationError.cause
                )
            }
                        
            if authenticationError.isNetworkError {
                return .networkError(
                    message: "Network connection failed",
                    cause: authenticationError
                )
            }
            
            
            if authenticationError.isMultifactorEnrollRequired {
                return .mfaEnrollRequired(
                    message: "MFA enrollment is required to continue",
                    cause: authenticationError
                )
            }

            if authenticationError.isMultifactorTokenInvalid {
                return .invalidMfaToken(
                    message: "The MFA token is invalid or has expired",
                    cause: authenticationError
                )
            }

            if authenticationError.isMultifactorCodeInvalid {
                return .invalidMfaCode(
                    message: "The MFA code is invalid or has expired",
                    cause: authenticationError
                )
            }

            if authenticationError.isAccessDenied {
                return .accessDenied(
                    message: "Access denied by authorization server",
                    cause: authenticationError
                )
            }

            if authenticationError.isLoginRequired {
                return .sessionExpired(
                    message: "Session expired, please login again",
                    cause: authenticationError
                )
            }

            if authenticationError.isInvalidRefreshToken {
                return .refreshTokenInvalid(
                    message: "Refresh token is invalid or expired",
                    cause: authenticationError
                )
            }

            if authenticationError.isRefreshTokenDeleted {
                return .refreshTokenDeleted(
                    message: "User account no longer exists",
                    cause: authenticationError
                )
            }

            if authenticationError.isTooManyAttempts {
                return .tooManyAttempts(
                    message: "Too many failed attempts, please try again later",
                    cause: authenticationError
                )
            }

            return .serverError(
                message: authenticationError.message,
                statusCode: authenticationError.statusCode,
                cause: authenticationError
            )
        } else {
            return .unknown(
                message: error.localizedDescription,
                cause: error.cause
            )
        }
    }

    static func handleMyAccountAuthError(error: MyAccountError) -> Auth0UIComponentError {
        if error.isNetworkError {
            return .networkError(
                message: "Network connection failed",
                cause: error
            )
        }

        if error.validationErrors?.isEmpty == false {
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

        if error.statusCode >= 500 {
            return .serverError(
                message: "Server error, please try again",
                statusCode: error.statusCode,
                cause: error
            )
        }
        return .unknown(
            message: error.detail,
            cause: error
        )
    }
}

struct FieldError {
    let field: String?
    let detail: String
    let pointer: String?
    let source: String?
}
