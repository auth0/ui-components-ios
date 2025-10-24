import Combine
import Auth0
import SwiftUI

final class MyAccountAuthMethodViewModel: ObservableObject {
    private let authMethods: [AuthenticationMethod]
    private let type: AuthMethodType
    private let dependencies: Dependencies

    init(authMethods: [AuthenticationMethod],
         type: AuthMethodType,
         dependencies: Dependencies) {
        self.authMethods = authMethods
        self.type = type
        self.dependencies = dependencies
    }

    func isAtleastOnceAuthFactorEnrolled() -> Bool {
        authMethods.first(where: { $0.confirmed == true }) != nil
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

enum AuthMethodType: String, CaseIterable {
    case email = "email"
    case sms = "phone"
    case totp = "totp"
    case pushNotification = "push-notification"
    case recoveryCode = "recovery-code"
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
        }
    }
    
    var savedAuthenticatorsCellTitle: String {
        switch self {
        case .email:
            "Email OTP"
        case .totp:
            "Authenticator App"
        case .pushNotification:
            "Push Notifications via Guardian"
        case .recoveryCode:
            "Recovery code generated"
        case .sms:
            "SMS OTP"
        }
    }

    private func isAtleastOnceAuthFactorEnrolled(_ authMethods: [AuthenticationMethod]) -> Bool {
        authMethods.first(where: { $0.confirmed == true }) != nil
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
            }
        }
    }
}
