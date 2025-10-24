import Auth0
import Foundation

enum UIComponentError: LocalizedError {
    case credentialsManager(CredentialsManagerError)
    case myAccountError(MyAccountError)
}
