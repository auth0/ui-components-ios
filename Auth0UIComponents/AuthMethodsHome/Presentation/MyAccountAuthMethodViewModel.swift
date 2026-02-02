import Combine
import Auth0
import SwiftUI

/// ViewModel for a single authentication method item in the My Account view.
final class MyAccountAuthMethodViewModel: ObservableObject {
    private let authMethods: [AuthenticationMethod]
    private let type: AuthMethodType
    private let dependencies: Auth0UIComponentsSDKInitializer

    init(authMethods: [AuthenticationMethod],
         type: AuthMethodType,
         dependencies: Auth0UIComponentsSDKInitializer) {
        self.authMethods = authMethods
        self.type = type
        self.dependencies = dependencies
    }

    func isAtleastOnceAuthFactorEnrolled() -> Bool {
        if type == .passkey {
            return authMethods.isEmpty == false
        }
        return authMethods.first(where: { $0.confirmed == true }) != nil
    }

    func title() -> String {
        type.title
    }

    func image() -> String {
        type.image
    }

    func handleNavigation() {
        Task {
            await NavigationStore.shared.push(type.navigationDestination(authMethods))
        }
    }
}

extension MyAccountAuthMethodViewModel: Hashable {
  
    static func == (lhs: MyAccountAuthMethodViewModel, rhs: MyAccountAuthMethodViewModel) -> Bool {
        lhs.type == rhs.type
    }

    func hash(into hasher: inout Hasher) {
        hasher.combine(authMethods)
    }
}

extension AuthenticationMethod: @retroactive Hashable {
    public func hash(into hasher: inout Hasher) {
        hasher.combine(id)
    }
}

/// Enum representing the different types of authentication methods available.
enum AuthMethodType: String, CaseIterable {
    case email = "email"

    case sms = "phone"

    case totp = "totp"

    case pushNotification = "push-notification"

    case recoveryCode = "recovery-code"

    case passkey = "passkey"
}

extension AuthMethodType {
    var title: String {
        switch self {
        case .email:
            "Email OTP"
        case .totp:
            "Authenticator App"
        case .pushNotification:
            "Push Notifications via Guardian"
        case .recoveryCode:
            "Recovery Code"
        case .sms:
            "SMS OTP"
        case .passkey:
            "Passkeys"
        }
    }

    var image: String {
        switch self {
        case .email:
            "email"
        case .pushNotification,
                .totp:
            "totp"
        case .recoveryCode:
            "code"
        case .sms:
            "sms"
        case .passkey:
            "passkey"
        }
    }

    var savedAuthenticatorsCellTitle: String {
        switch self {
        case .email:
            "Email"
        case .totp:
            "Authenticator"
        case .pushNotification:
            "Push"
        case .recoveryCode:
            "Recovery code"
        case .sms:
            "Phone"
        case .passkey:
            "Passkey"
        }
    }

    var savedAuthenticatorsTitle: String  {
        switch self {
        case .email:
            "Saved Emails for OTP"
        case .sms:
            "Saved Phones for SMS OTP"
        case .totp:
            "Saved Authenticators"
        case .pushNotification:
            "Saved Apps for Push"
        case .recoveryCode:
            "Generated Recovery code"
        case .passkey:
            "Saved on your devices"
        }
    }

    var savedAuthenticatorsNavigationTitle : String {
        switch self {
        case .pushNotification:
            "Push Notification"
        case .totp:
            "Authenticator"
        case .recoveryCode:
            "Recovery Code"
        case .email:
            "Email OTP"
        case .sms:
            "Phone for SMS OTP"
        case .passkey:
            "Passkeys"
        }
    }

    var confirmationDialogTitle: String {
        switch self {
        case .pushNotification:
            "Manage your Push Notification"
        case .totp:
            "Manage your Authenticator"
        case .recoveryCode:
            "Manage your Recovery Code"
        case .email:
            "Manage your email"
        case .sms:
            "Manage your phone for SMS OTP"
        case .passkey:
            "Manage your passkey"
        }
    }

    var confirmationDialogDestructiveButtonTitle: String {
        switch self {
        case .pushNotification:
            "Revoke"
        case .totp:
            "Revoke"
        case .recoveryCode,
                .email,
                .sms,
                .passkey:
            "Remove"
        }
    }

    var savedAuthenticatorsEmptyStateMessage: String {
        switch self {
        case .pushNotification:
            return "No Push Notification was added."
        case .email:
            return "No Email was saved."
        case .recoveryCode:
            return "No Recovery Code was generated."
        case .sms:
            return "No Phone was saved."
        case .totp:
            return "No Authenticator was added."
        case .passkey:
            return "No passkeys saved"
        }
    }

    private func isAtleastOnceAuthFactorEnrolled(_ authMethods: [AuthenticationMethod]) -> Bool {
        if self == .passkey {
            return authMethods.isEmpty == false
        }
        return authMethods.first(where: { $0.confirmed == true }) != nil
    }

    func navigationDestination(_ authMethods: [AuthenticationMethod]) -> Route {
        if isAtleastOnceAuthFactorEnrolled(authMethods) == true {
           return .filteredAuthListScreen(type: self, authMethods: authMethods)
        } else {
            switch self {
            case .pushNotification,
                    .totp:
                return .totpPushQRScreen(type: self)
            case .email:
               return .emailPhoneEnrollmentScreen(type: .email)
            case .sms:
               return .emailPhoneEnrollmentScreen(type: self)
            case .recoveryCode:
               return .recoveryCodeScreen
            case .passkey:
                return .enrollPasskeyScreen
            }
        }
    }
}
