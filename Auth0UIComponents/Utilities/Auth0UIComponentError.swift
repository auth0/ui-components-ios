import Auth0

enum Auth0UIComponentError {

    case accessDenied(message: String = "Access denied",
                      cause: Error? = nil)

    // MFA Related Errors
    case mfaRequired(message: String = "Multi-factor authentication required",
                     cause: Error? = nil)

    case mfaEnrollRequired(message: String = "MFA enrollment required",
                           cause: Error? = nil)

    case invalidMfaCode(message: String = "Invalid or expired MFA code",
                        cause: Error? = nil)

    case invalidMfaToken(message: String = "Invalid or expired MFA token",
                         cause: Error? = nil)

    // Token & Session Errors
    case refreshTokenInvalid(message: String = "Invalid or expired refresh token",
                             cause: Error? = nil)

    case refreshTokenDeleted(message: String = "Refresh token no longer exists",
                             cause: Error? = nil)

    case sessionExpired(message: String = "Session has expired, please login again",
                        cause: Error? = nil)

    // Rate Limiting & Security
    case tooManyAttempts(message: String = "Too many login attempts, account temporarily blocked",
                         cause: Error? = nil)

    // Network Errors
    case networkError(message: String = "Network connection failed",
                      cause: Error? = nil)

    case timeout(message: String = "Request timed out",
                 cause: Error? = nil)

    // Validation Errors
    case validationError(
        message: String = "Validation failed",
        cause: Error? = nil,
        errors: [FieldError] = []
    )

    // Server Errors
    case serverError(message: String = "Server error occurred",
                     statusCode: Int,
                     cause: Error? = nil)

    // Generic/Unknown Errors
    case unknown(message: String = "An unknown error occurred",
                 cause: Error? = nil)
}

extension Auth0UIComponentError {
    func errorViewModel(completion: @escaping () -> Void) -> ErrorScreenViewModel? {
        switch self {
        case  .networkError:
            return ErrorScreenViewModel(title: "Connection problem", subTitle: "Please check your internet connection", buttonTitle: "Try again", buttonClick: {
                completion()
            })
        case  .invalidMfaCode:
            return ErrorScreenViewModel(title: "Invalid verification code", subTitle: "The code you entered is incorrect or has expired. Please try again.", buttonTitle: "Try again", buttonClick: {
                completion()
            })
        case .sessionExpired:
            return ErrorScreenViewModel(title: "Session expired", subTitle: "Your session has expired. Please login again to continue.", buttonTitle: "Try again", buttonClick: {
                completion()
            })
        case .tooManyAttempts:
            return ErrorScreenViewModel(title: "Too many attempts", subTitle: "Your account has been temporarily blocked due to too many failed attempts. Please try again later.", buttonTitle: "Try again", buttonClick: {
                completion()
            })
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
                .unknown(let message, _):
            return ErrorScreenViewModel(title: message, subTitle: "We are unable to process your request. Please try again in a few minutes.", buttonTitle: "Try again", buttonClick: {
                completion()
            })
        }
    }
    
    static func handleCredentialsManagerError(error: CredentialsManagerError) -> Auth0UIComponentError {
        if let authenticationError = error.cause as? AuthenticationError {
            if authenticationError.isMultifactorRequired {
                return .mfaRequired(message: "Multi-factor authentication is required", cause: authenticationError.cause)
            }
            
            if authenticationError.isNetworkError {
                return .networkError(message: "Network connection failed", cause: authenticationError)
            }
            
            if authenticationError.isMultifactorEnrollRequired {
                return .mfaEnrollRequired(message: "MFA enrollment is required to continue", cause: authenticationError)
            }
            
            if authenticationError.isMultifactorTokenInvalid {
                return .invalidMfaToken(message: "The MFA token is invalid or has expired", cause: authenticationError)
            }
            
            if authenticationError.isMultifactorCodeInvalid {
                return .invalidMfaCode(message: "The MFA code is invalid or has expired", cause: authenticationError)
            }
            
            if authenticationError.isAccessDenied {
                return .accessDenied(message: "Access denied by authorization server", cause: authenticationError)
            }
            
            if authenticationError.isLoginRequired {
                return .sessionExpired(message: "Session expired, please login again", cause: authenticationError)
            }
            if authenticationError.isInvalidRefreshToken {
                return .refreshTokenInvalid(message: "Refresh token is invalid or expired", cause: authenticationError)
            }
            
            if authenticationError.isRefreshTokenDeleted {
                return .refreshTokenDeleted(message: "User account no longer exists", cause: authenticationError)
            }
            
            if authenticationError.isTooManyAttempts {
                return .tooManyAttempts(message: "Too many failed attempts, please try again later", cause: authenticationError)
            }
            return .serverError(message: authenticationError.message, statusCode: authenticationError.statusCode, cause: authenticationError)
        } else {
            return .unknown(message: error.localizedDescription, cause: error.cause)
        }
    }
    
    static func handleMyAccountAuthError(error: MyAccountError) -> Auth0UIComponentError {
        if error.isNetworkError {
            return .networkError(message: "Network connection failed", cause: error)
        }

        if error.validationErrors?.isEmpty == false {
            return .validationError(message: error.detail, cause: error, errors: (error.validationErrors ?? []).map { _ in
                FieldError(field: nil,
                           detail: "",
                           pointer: nil,
                           source: nil)
                // TODO: change to below
               // FieldError(field: $0.field, detail: $0.detail, pointer: $0.pointer, source: $0.source)
            })
        }

        if error.statusCode >= 500 {
            return Auth0UIComponentError.serverError(message: "Server error, please try again", statusCode: error.statusCode, cause: error)
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
