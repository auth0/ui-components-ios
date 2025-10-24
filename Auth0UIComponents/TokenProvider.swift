import Auth0
import Combine

public protocol TokenProvider {
    func fetchCredentials() async throws -> Credentials
    func fetchCredentials() -> AnyPublisher<Credentials, CredentialsManagerError>
    func storeCredentials(_ credentials: Credentials)
    func fetchAPICredentials(audience: String, scope: String) async throws -> APICredentials
    func fetchAPICredentials(audience: String, scope: String) -> AnyPublisher<APICredentials, CredentialsManagerError>
}

//extension CredentialsManager: @retroactive Hashable {
//    public func hash(into hasher: inout Hasher) {
//        hasher.combine()
//    }
//}
//
//extension CredentialsManager: @retroactive Equatable {
//    public static func == (lhs: CredentialsManager, rhs: CredentialsManager) -> Bool {
//        lhs.
//    }
//}

extension CredentialsManager: TokenProvider {

    public func fetchCredentials() async throws -> Credentials {
        try await credentials()
    }

    public func fetchCredentials() -> AnyPublisher<Credentials, CredentialsManagerError> {
        credentials()
    }

    public func storeCredentials(_ credentials: Credentials) {
        _ = store(credentials: credentials)
    }

    public func fetchAPICredentials(audience: String, scope: String) async throws -> APICredentials {
        try await apiCredentials(forAudience: audience, scope: scope)
    }

    public func fetchAPICredentials(audience: String, scope: String) -> AnyPublisher<APICredentials, CredentialsManagerError> {
        apiCredentials(forAudience: audience, scope: scope)
    }
}
