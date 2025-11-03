import Foundation
final class Dependencies {
    let audience: String
    let domain: String
    let clientId: String
    let tokenProvider: TokenProvider
    let bundle: Bundle
    let session: URLSession

    static private var _shared: Dependencies?

    static var shared: Dependencies {
        guard let instance = _shared else {
            fatalError("AppDependencies not initialized. Call `AppDependencies.initialize(...)` first!")
        }
        return instance
    }

    private init(audience: String,
                 domain: String,
                 clientId: String,
                 bundle: Bundle = .main,
                 session: URLSession = .shared,
                 tokenProvider: any TokenProvider) {
        self.audience = audience
        self.domain = domain
        self.clientId = clientId
        self.tokenProvider = tokenProvider
        self.bundle = bundle
        self.session = session
    }

    static func initialize(
        audience: String,
        domain: String,
        clientId: String,
        bundle: Bundle,
        session: URLSession,
        tokenProvider: any TokenProvider
    ) {
        guard _shared == nil else {
            fatalError("AppDependencies already initialized!")
        }
        _shared = Dependencies(audience: audience,
                               domain: domain,
                               clientId: clientId,
                               bundle: bundle,
                               session: session,
                               tokenProvider: tokenProvider)
    }
}
