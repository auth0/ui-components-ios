import Foundation
import Testing

struct MockColor {
    init(_ name: String, bundle: MockResourceBundle?) {}
}
typealias Color = MockColor

struct MockResourceBundle {
    static let `default`: MockResourceBundle? = MockResourceBundle()
}
typealias ResourceBundle = MockResourceBundle

struct MockAttributedString: Equatable {
    var string: String
    var isUnderlined: Bool = false
    
    init(_ string: String) { self.string = string }
    
    static func == (lhs: MockAttributedString, rhs: MockAttributedString) -> Bool {
        return lhs.string == rhs.string && lhs.isUnderlined == rhs.isUnderlined
    }
    
    subscript(range: Range<String.Index>) -> MockAttributedString {
        get { return self }
        set { /* No-op for testing */ }
    }
    
    func range(of string: String) -> Range<String.Index>? {
        return self.string.range(of: string)
    }
    
    struct MockUnderlineStyle {}
    var underlineStyle: MockUnderlineStyle? {
        didSet { if underlineStyle != nil { isUnderlined = true } }
    }
}
typealias AttributedString = MockAttributedString

extension MockAttributedString {
    mutating func setForegroundColor(_ color: Color?) {
    }
}

struct ErrorScreenViewModel: Equatable {
    let title: String
    let subTitle: AttributedString
    let buttonTitle: String
    let textTap: () -> Void
    let buttonClick: () -> Void

    static func == (lhs: ErrorScreenViewModel, rhs: ErrorScreenViewModel) -> Bool {
        return lhs.title == rhs.title &&
               lhs.subTitle == rhs.subTitle &&
               lhs.buttonTitle == rhs.buttonTitle
    }
}

var openedContactUsLink = false
class MockApplication {
    static let shared = MockApplication()
    func open(_ url: URL) {
        if url.absoluteString == "https://auth0.com/contact-us" {
            openedContactUsLink = true
        }
    }
}
#if !os(macOS)
typealias UIApplication = MockApplication
#else
typealias NSWorkspace = MockApplication
#endif

enum MockWebAuthError: Error, Equatable {
    static func == (lhs: MockWebAuthError, rhs: MockWebAuthError) -> Bool {
        lhs.message == rhs.message
    }

    case userCancelled
    case other(message: String, cause: Error?)

    var message: String {
        switch self {
        case .userCancelled: return "User cancelled"
        case .other(let message, _): return message
        }
    }
    var cause: Error? {
        switch self {
        case .userCancelled: return nil
        case .other(_, let cause): return cause
        }
    }
}
typealias WebAuthError = MockWebAuthError

struct MockAuthenticationError: Error {
    let message: String
    let statusCode: Int
    let cause: Error?
    let code: String
    
    var isMultifactorRequired: Bool { code == "mfa_required" }
    var isNetworkError: Bool { statusCode == -1009 || code == "network_error" }
    var isMultifactorEnrollRequired: Bool { code == "mfa_enroll_required" }
    var isMultifactorTokenInvalid: Bool { code == "invalid_mfa_token" }
    var isMultifactorCodeInvalid: Bool { code == "invalid_mfa_code" }
    var isAccessDenied: Bool { code == "access_denied" }
    var isLoginRequired: Bool { code == "login_required" }
    var isInvalidRefreshToken: Bool { code == "invalid_grant" && message.contains("refresh token") }
    var isRefreshTokenDeleted: Bool { code == "invalid_grant" && message.contains("deleted") }
    var isTooManyAttempts: Bool { code == "too_many_attempts" }
}
typealias AuthenticationError = MockAuthenticationError

struct MockCredentialsManagerError: Error {
    let cause: Error?
    let localizedDescription: String
}
typealias CredentialsManagerError = MockCredentialsManagerError

struct MockMyAccountError: Error {
    let detail: String
    let statusCode: Int
    let validationErrors: [FieldError]?
    var isNetworkError: Bool { statusCode == -1009 }
}
typealias MyAccountError = MockMyAccountError

// MARK: - Original Code Definitions

struct FieldError {
    let field: String?
    let detail: String
    let pointer: String?
    let source: String?
}

enum Auth0UIComponentError {
    // MARK: Web Auth Errors
    case idTokenValidationFailed(message: String, cause: Error? = nil)
    case noBundleIdentifier(message: String, cause: Error? = nil)
    case userCancelled(message: String = "Something went wrong", cause: Error? = nil)
    case transactionActiveAlready(message: String, cause: Error? = nil)
    case pkceNotAllowed(message: String, cause: Error? = nil)
    case invalidInvitationURL(message: String, cause: String? = nil)
    case noAuthorizationCode(message: String, cause: String? = nil)
    case accessDenied(message: String = "Access denied", cause: Error? = nil)

    // MARK: MFA Related Errors
    case mfaRequired(message: String = "Multi-factor authentication required", cause: Error? = nil)
    case mfaEnrollRequired(message: String = "MFA enrollment required", cause: Error? = nil)
    case invalidMfaCode(message: String = "Invalid or expired MFA code", cause: Error? = nil)
    case invalidMfaToken(message: String = "Invalid or expired MFA token", cause: Error? = nil)

    // MARK: Token & Session Errors
    case refreshTokenInvalid(message: String = "Invalid or expired refresh token", cause: Error? = nil)
    case refreshTokenDeleted(message: String = "Refresh token no longer exists", cause: Error? = nil)
    case sessionExpired(message: String = "Session has expired, please login again", cause: Error? = nil)

    // MARK: Rate Limiting & Security
    case tooManyAttempts(message: String = "Too many login attempts, account temporarily blocked", cause: Error? = nil)

    // MARK: Network Errors
    case networkError(message: String = "Network connection failed", cause: Error? = nil)
    case timeout(message: String = "Request timed out", cause: Error? = nil)

    // MARK: Validation Errors
    case validationError(message: String = "Validation failed", cause: Error? = nil, errors: [FieldError] = [])

    // MARK: Server Errors
    case serverError(message: String = "Server error occurred", statusCode: Int, cause: Error? = nil)

    // MARK: Generic/Unknown Errors
    case unknown(message: String = "An unknown error occurred", cause: Error? = nil)
}

extension Auth0UIComponentError {
    func errorViewModel(completion: @escaping () -> Void) -> ErrorScreenViewModel? {
        switch self {
        case  .networkError:
            var subTitleText = AttributedString("Please check your internet connection")
            subTitleText.setForegroundColor(Color("737373", bundle: ResourceBundle.default))
            return ErrorScreenViewModel(title: "Connection problem", subTitle: subTitleText, buttonTitle: "Try again", textTap: {}, buttonClick: {
                completion()
            })
        case  .invalidMfaCode:
            var subTitleText = AttributedString("The code you entered is incorrect or has expired. Please try again.")
            subTitleText.setForegroundColor(Color("737373", bundle: ResourceBundle.default))
            return ErrorScreenViewModel(title: "Invalid verification code", subTitle: subTitleText, buttonTitle: "Try again", textTap: {}, buttonClick: {
                completion()
            })
        case .sessionExpired:
            var subTitleText = AttributedString("Your session has expired. Please login again to continue.")
            subTitleText.setForegroundColor(Color("737373", bundle: ResourceBundle.default))
            return ErrorScreenViewModel(title: "Session expired", subTitle: subTitleText, buttonTitle: "Try again", textTap: {}, buttonClick: {
                completion()
            })
        case .tooManyAttempts:
            let subTitleString = "Your account has been temporarily blocked due to too many failed attempts. Please try again later."
            var subTitleText = AttributedString(subTitleString)
            subTitleText.setForegroundColor(Color("737373", bundle: ResourceBundle.default))
            return ErrorScreenViewModel(title: "Too many attempts", subTitle: AttributedString(subTitleString), buttonTitle: "Try again", textTap: {
                
            }, buttonClick: {
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
             .unknown(let message, _),
             .invalidInvitationURL(let message, _),
             .noBundleIdentifier(let message, _),
             .pkceNotAllowed(let message, _),
             .noAuthorizationCode(let message, _),
             .transactionActiveAlready(let message, _),
             .idTokenValidationFailed(let message, _),
             .userCancelled(let message, _):
            
            let genericSubTitle = "We are unable to process your request. Please try again in a few minutes. If this problem persists, please contact us."
            var full = AttributedString(genericSubTitle)
            full.setForegroundColor(Color("737373", bundle: ResourceBundle.default))
            if let range = full.range(of: "contact us.") {
                full[range].underlineStyle = MockAttributedString.MockUnderlineStyle()
            }
            
            return ErrorScreenViewModel(title: message, subTitle: full, buttonTitle: "Try again", textTap: {
                if let url = URL(string: "https://auth0.com/contact-us") {
                    #if os(macOS)
                        NSWorkspace.shared.open(url)
                    #else
                        UIApplication.shared.open(url)
                    #endif
                }
            }, buttonClick: {
                completion()
            })
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
            return .validationError(message: error.detail, cause: error, errors: (error.validationErrors ?? []).map {
                FieldError(field: $0.field, detail: $0.detail, pointer: $0.pointer, source: $0.source)
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


// MARK: - Swift Testing Implementation

struct Auth0UIComponentErrorSwiftTests {
    
    // MARK: - View Model Generation Tests
    
    @Test func testNetworkErrorViewModel() {
        let error = Auth0UIComponentError.networkError()
        var completionCalled = false
        
        guard let viewModel = error.errorViewModel(completion: { completionCalled = true }) else {
            Issue.record("ViewModel should not be nil for networkError")
            return
        }
        
        #expect(viewModel.title == "Connection problem")
        #expect(viewModel.subTitle.string == "Please check your internet connection")
        #expect(viewModel.buttonTitle == "Try again")
        
        viewModel.buttonClick()
        #expect(completionCalled, "Button click should call the completion handler.")
    }

    @Test func testInvalidMfaCodeViewModel() {
        let error = Auth0UIComponentError.invalidMfaCode()
        var completionCalled = false

        guard let viewModel = error.errorViewModel(completion: { completionCalled = true }) else {
            Issue.record("ViewModel should not be nil for invalidMfaCode")
            return
        }
        
        #expect(viewModel.title == "Invalid verification code")
        #expect(viewModel.subTitle.string == "The code you entered is incorrect or has expired. Please try again.")
        
        viewModel.buttonClick()
        #expect(completionCalled, "Button click should call the completion handler.")
    }

    @Test func testMfaRequiredReturnsNilViewModel() {
        let error = Auth0UIComponentError.mfaRequired()
        let viewModel = error.errorViewModel(completion: {})
        
        #expect(viewModel == nil, "mfaRequired should return nil ViewModel")
    }
    
    @Test func testGenericErrorViewModel_textTapOpensURL() {
        let testMessage = "Unknown Server Error"
        let error = Auth0UIComponentError.unknown(message: testMessage)
        
        guard let viewModel = error.errorViewModel(completion: {}) else {
            Issue.record("Generic error should not be nil")
            return
        }

        openedContactUsLink = false
        viewModel.textTap()
        
        #expect(openedContactUsLink, "Text tap should attempt to open the contact us URL.")
    }

    // MARK: - WebAuth Handling Tests

    @Test func testHandleWebAuthError_userCancelled() {
        let error = WebAuthError.userCancelled
        let convertedError = Auth0UIComponentError.handleWebAuthError(error: error)
        
        if case .userCancelled(let message, _) = convertedError {
            #expect(message == "Something went wrong", "User cancelled should use the default message.")
        } else {
            Issue.record("#expected .userCancelled, got \(convertedError)")
        }
    }

    @Test func testHandleWebAuthError_otherError() {
        let customError = NSError(domain: "TestDomain", code: 123, userInfo: nil)
        let error = WebAuthError.other(message: "Custom web auth error", cause: customError)
        let convertedError = Auth0UIComponentError.handleWebAuthError(error: error)
        
        if case .unknown(let message, _) = convertedError {
            #expect(message == "Custom web auth error")
        } else {
            Issue.record("#expected .unknown, got \(convertedError)")
        }
    }

    // MARK: - CredentialsManager Handling Tests

    @Test func testHandleCredentialsManagerError_mfaRequired() {
        let authError = AuthenticationError(message: "MFA needed", statusCode: 401, cause: nil, code: "mfa_required")
        let error = CredentialsManagerError(cause: authError, localizedDescription: "CM failure")
        let convertedError = Auth0UIComponentError.handleCredentialsManagerError(error: error)
        
        if case .mfaRequired(let message, _) = convertedError {
            #expect(message == "Multi-factor authentication is required")
        } else {
            Issue.record("#expected .mfaRequired, got \(convertedError)")
        }
    }

    @Test func testHandleCredentialsManagerError_networkError() {
        let authError = AuthenticationError(message: "Network failure", statusCode: -1009, cause: nil, code: "timeout")
        let error = CredentialsManagerError(cause: authError, localizedDescription: "CM failure")
        let convertedError = Auth0UIComponentError.handleCredentialsManagerError(error: error)
        
        if case .networkError(let message, _) = convertedError {
            #expect(message == "Network connection failed")
        } else {
            Issue.record("#expected .networkError, got \(convertedError)")
        }
    }
    
    @Test func testHandleCredentialsManagerError_sessionExpired() {
        let authError = AuthenticationError(message: "Login required", statusCode: 401, cause: nil, code: "login_required")
        let error = CredentialsManagerError(cause: authError, localizedDescription: "CM failure")
        let convertedError = Auth0UIComponentError.handleCredentialsManagerError(error: error)
        
        if case .sessionExpired(let message, _) = convertedError {
            #expect(message == "Session expired, please login again")
        } else {
            Issue.record("#expected .sessionExpired, got \(convertedError)")
        }
    }

    @Test func testHandleCredentialsManagerError_serverErrorFallback() {
        let authError = AuthenticationError(message: "A bad server error", statusCode: 500, cause: nil, code: "server_error")
        let error = CredentialsManagerError(cause: authError, localizedDescription: "CM failure")
        let convertedError = Auth0UIComponentError.handleCredentialsManagerError(error: error)
        
        if case .serverError(let message, let statusCode, _) = convertedError {
            #expect(message == "A bad server error")
            #expect(statusCode == 500)
        } else {
            Issue.record("#expected .serverError, got \(convertedError)")
        }
    }

    // MARK: - MyAccountAuth Handling Tests
    
    @Test func testHandleMyAccountAuthError_networkError() {
        let error = MyAccountError(detail: "Network timed out", statusCode: -1009, validationErrors: nil)
        let convertedError = Auth0UIComponentError.handleMyAccountAuthError(error: error)
        
        if case .networkError(let message, _) = convertedError {
            #expect(message == "Network connection failed")
        } else {
            Issue.record("#expected .networkError, got \(convertedError)")
        }
    }

    @Test func testHandleMyAccountAuthError_validationError() {
        let fieldErrors = [FieldError(field: "email", detail: "Invalid format", pointer: nil, source: nil)]
        let error = MyAccountError(detail: "Validation failed", statusCode: 400, validationErrors: fieldErrors)
        let convertedError = Auth0UIComponentError.handleMyAccountAuthError(error: error)
        
        if case .validationError(let message, _, let errors) = convertedError {
            #expect(message == "Validation failed")
            #expect(errors.count == 1)
            #expect(errors.first?.field == "email")
        } else {
            Issue.record("#expected .validationError, got \(convertedError)")
        }
    }

    @Test func testHandleMyAccountAuthError_serverError() {
        let error = MyAccountError(detail: "Database offline", statusCode: 503, validationErrors: nil)
        let convertedError = Auth0UIComponentError.handleMyAccountAuthError(error: error)
        
        if case .serverError(let message, let statusCode, _) = convertedError {
            #expect(message == "Server error, please try again")
            #expect(statusCode == 503)
        } else {
            Issue.record("#expected .serverError, got \(convertedError)")
        }
    }
}
