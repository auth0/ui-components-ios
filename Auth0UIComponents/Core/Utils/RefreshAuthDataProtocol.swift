/// Protocol for objects that need to refresh authentication data.
protocol RefreshAuthDataProtocol: AnyObject {
    func refreshAuthData()
}
