import Auth0

extension AuthenticationMethod: Equatable {
    public static func == (lhs: AuthenticationMethod, rhs: AuthenticationMethod) -> Bool {
        lhs.id == rhs.id
    }
}
