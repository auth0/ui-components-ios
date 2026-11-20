import Auth0
import Foundation

/// Factory for creating MyAccount API clients with telemetry pre-applied.
///
/// All UseCases should use this factory instead of calling `Auth0.myAccount()` directly.
/// This ensures the `Auth0-Client` header identifies requests as originating from
/// the UI Components SDK.
struct MyAccountClientFactory {
    static func create(token: String, domain: String, session: URLSession = .shared) -> MyAccount {
        var client = Auth0.myAccount(token: token, domain: domain, session: session)
        client.using(inLibrary: libraryName, version: version)
        return client
    }

    static func create(token: String, domain: String) -> MyAccount {
        var client = Auth0.myAccount(token: token, domain: domain)
        client.using(inLibrary: libraryName, version: version)
        return client
    }
}
