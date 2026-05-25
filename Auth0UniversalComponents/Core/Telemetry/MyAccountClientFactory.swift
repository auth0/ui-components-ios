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
        if TelemetryManager.shared.enabled {
            client.using(inLibrary: "Auth0UniversalComponents", version: version)
        } else {
            client.tracking(enabled: false)
        }
        return client
    }

    static func create(token: String, domain: String) -> MyAccount {
        var client = Auth0.myAccount(token: token, domain: domain)
        if TelemetryManager.shared.enabled {
            client.using(inLibrary: "Auth0UniversalComponents", version: version)
        } else {
            client.tracking(enabled: false)
        }
        return client
    }
}
