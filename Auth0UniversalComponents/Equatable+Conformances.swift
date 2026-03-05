import Auth0

/// Makes AuthenticationMethod from Auth0 SDK conform to Equatable.
///
/// Compares authentication methods by their unique identifier.
extension AuthenticationMethod: @retroactive Equatable {
    /// Compares two authentication methods by their ID.
    ///
    /// - Parameters:
    ///   - lhs: The left-hand side authentication method
    ///   - rhs: The right-hand side authentication method
    /// - Returns: True if both methods have the same ID
    public static func == (lhs: AuthenticationMethod, rhs: AuthenticationMethod) -> Bool {
        lhs.id == rhs.id
    }
}
