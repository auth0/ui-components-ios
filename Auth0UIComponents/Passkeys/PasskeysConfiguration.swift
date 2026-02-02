public struct PasskeysConfiguration {
    let userIdentityId: String?
    let connection: String?
    
    public init(userIdentityId: String? = nil,
                connection: String? = nil) {
        self.userIdentityId = userIdentityId
        self.connection = connection
    }
}
