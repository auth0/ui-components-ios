@testable import Auth0UIComponents
import Foundation
import Auth0

struct MockTokenProvider: TokenProvider {

    func fetchCredentials() async throws -> Credentials {
        Credentials(accessToken: "mock-access-token")
    }
    
    func storeCredentials(credentials: Credentials) {}
    
    func store(apiCredentials: APICredentials, for audience: String) {}
    
    func fetchAPICredentials(audience: String, scope: String) async throws -> APICredentials {
        APICredentials(accessToken: "mock-access-token", tokenType: "Bearer", expiresIn: Date(), scope: "openid profile offline_access")
    }
}
