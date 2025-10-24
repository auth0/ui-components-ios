import SwiftUI
import Combine
import Foundation
import Auth0

enum Route: Hashable {
    case emailPhoneEnrollmentScreen(type: AuthMethodType)
    case totpPushQRScreen(type: AuthMethodType)
    case recoveryCodeScreen
    case otpScreen(type: AuthMethodType,
                   emailOrPhoneNumber: String? = nil,
                   totpEnrollmentChallege: TOTPEnrollmentChallenge? = nil,
                   phoneEnrollmentChallenge: PhoneEnrollmentChallenge? = nil,
                   emailEnrollmentChallenge: EmailEnrollmentChallenge? = nil)
    case filteredAuthListScreen(type: AuthMethodType,
                                authMethods: [AuthenticationMethod])
}

extension AuthMethodType: Hashable {
    
}

extension TOTPEnrollmentChallenge: @retroactive Hashable {
    public static func == (lhs: TOTPEnrollmentChallenge, rhs: TOTPEnrollmentChallenge) -> Bool {
        lhs.authenticationId == rhs.authenticationId
    }

    public func hash(into hasher: inout Hasher) {
        hasher.combine(authenticationId)
    }
}

extension PhoneEnrollmentChallenge: @retroactive Hashable {
    public static func == (lhs: PhoneEnrollmentChallenge, rhs: PhoneEnrollmentChallenge) -> Bool {
        lhs.authenticationId == rhs.authenticationId
    }

    public func hash(into hasher: inout Hasher) {
        hasher.combine(authenticationId)
    }
}

extension EmailEnrollmentChallenge: @retroactive Hashable {
    public static func == (lhs: EmailEnrollmentChallenge, rhs: EmailEnrollmentChallenge) -> Bool {
        lhs.authenticationId == rhs.authenticationId
    }

    public func hash(into hasher: inout Hasher) {
        hasher.combine(authenticationId)
    }
}

struct AnyTokenProvider: Hashable {
    private let base: any TokenProvider
    private let _hash: (inout Hasher) -> Void
    private let _equals: (any TokenProvider) -> Bool

    init<T: TokenProvider & Hashable>(_ base: T) {
        self.base = base
        self._hash = base.hash(into:)
        self._equals = { other in
            guard let other = other as? T else { return false }
            return base == other
        }
    }

    func hash(into hasher: inout Hasher) {
        _hash(&hasher)
    }

    static func == (lhs: AnyTokenProvider, rhs: AnyTokenProvider) -> Bool {
        lhs._equals(rhs.base)
    }

    func asTokenProvider() -> any TokenProvider {
        base
    }
}

final class Dependencies {
    let audience: String
    let domain: String
    let tokenProvider: TokenProvider
    
    static private var _shared: Dependencies?
    
    static var shared: Dependencies {
        guard let instance = _shared else {
            fatalError("AppDependencies not initialized. Call `AppDependencies.initialize(...)` first!")
        }
        return instance
    }
    
    private init(audience: String,
                 domain: String,
                 tokenProvider: any TokenProvider) {
        self.audience = audience
        self.domain = domain
        self.tokenProvider = tokenProvider
    }
    
    static func initialize(
        audience: String,
        domain: String,
        tokenProvider: any TokenProvider
    ) {
        guard _shared == nil else {
            fatalError("AppDependencies already initialized!")
        }
        _shared = Dependencies(audience: audience,
                               domain: domain,
                               tokenProvider: tokenProvider)
    }
}

@MainActor
final class NavigationStore: ObservableObject {
    @Published var path: [Route] = []
    
    static let shared = NavigationStore()
    private init() {}
    
    private let queue = DispatchQueue(label: "NavigationStoreQueue")
        
    func push(_ route: Route) {
        path.append(route)
    }
    
    func pop() {
        if !path.isEmpty {
            path.removeLast()
        }
    }
    
    func popToRoot() {
        path.removeLast(path.count)
    }
    
    func reset() {
        path = []
    }
}
