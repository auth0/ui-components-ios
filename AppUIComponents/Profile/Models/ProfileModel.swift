import Foundation

public struct ProfileModel: Hashable {
    // MARK: - Properties
    let name: String
    let givenName: String?
    let familyName: String?
    let email: String?
    let emailVerified: Bool?
    let lastUpdatedAt: Date?
    
    // MARK: - Init
    init(name: String, givenName: String?, familyName: String?, email: String?, emailVerified: Bool?, lastUpdatedAt: Date?) {
        self.name = name
        self.givenName = givenName
        self.familyName = familyName
        self.email = email
        self.emailVerified = emailVerified
        self.lastUpdatedAt = lastUpdatedAt
    }
}
