@testable import Auth0UIComponents
import Combine
import Foundation
import Auth0

final class MockCredentialsManager: TokenProvider {
    func fetchCredentials() async throws -> Auth0.Credentials {
        Credentials()
    }
    
    func fetchCredentials() -> AnyPublisher<Auth0.Credentials, Auth0.CredentialsManagerError> {
        return Just(Credentials())
            .setFailureType(to: CredentialsManagerError.self)
            .eraseToAnyPublisher()
    }
    
    func storeCredentials(_ credentials: Auth0.Credentials) {
        
    }
    
    func fetchAPICredentials(audience: String, scope: String) async throws -> Auth0.APICredentials {
        APICredentials(accessToken: "", tokenType: "", expiresIn: Date(), scope: "")
    }
    
    func fetchAPICredentials(audience: String, scope: String) -> AnyPublisher<Auth0.APICredentials, Auth0.CredentialsManagerError> {
        return Just(APICredentials(accessToken: "", tokenType: "", expiresIn: Date(), scope: ""))
            .setFailureType(to: CredentialsManagerError.self)
            .eraseToAnyPublisher()
    }
    
    
}
