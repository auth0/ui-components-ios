/// Protocol for delegates that need to refresh authentication data after operations complete.
///
/// This protocol is used to notify view models or other components when authentication
/// data has changed (e.g., after enrolling in a new authentication method) and needs
/// to be refreshed from the server.
///
/// Implementations should re-fetch the current user's authentication methods and update
/// their internal state accordingly.
protocol RefreshAuthDataProtocol: AnyObject {
    /// Refreshes the authentication data, typically by fetching updated methods from the server.
    func refreshAuthData()
}
