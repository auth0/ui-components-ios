import Combine
import Foundation
@testable import Auth0UIComponents
import Auth0

final class MockCredentialsManager: TokenProvider {
    func fetchCredentials() async throws -> Credentials {
        Credentials()
    }
    
    func storeCredentials(credentials: Auth0.Credentials) {
        
    }
    
    func store(apiCredentials: Auth0.APICredentials, for audience: String) {
        
    }
    
    func fetchAPICredentials(audience: String, scope: String) async throws -> APICredentials {
        APICredentials(from: Credentials())
    }
}
