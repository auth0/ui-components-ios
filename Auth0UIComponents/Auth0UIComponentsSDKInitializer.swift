import Foundation
import Auth0

public actor Auth0UIComponentsSDKInitializer {
    let audience: String
    let domain: String
    let clientId: String
    let tokenProvider: TokenProvider
    let bundle: Bundle
    let session: URLSession
    static private var _shared: Auth0UIComponentsSDKInitializer?

    static var shared: Auth0UIComponentsSDKInitializer {
        guard let instance = _shared else {
            fatalError("Auth0UIComponentsSDKInitializer not initialized. Call Auth0UIComponentsSDKInitializer.initialize(...) first!")
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

    public static func initialize(session: URLSession = .shared,
                                  bundle: Bundle = .main,
                                  tokenProvider: any TokenProvider) {
        let config = plistValues(bundle: bundle)!

        let myAccountAudience = config.domain.appending("/me/")
        
        _shared = Auth0UIComponentsSDKInitializer(audience: ensureHTTPS(myAccountAudience),
                                    domain: config.domain,
                                    clientId: config.clientId,
                                    bundle: bundle,
                                    session: session,
                                    tokenProvider: tokenProvider)
    }

    public static func initialize(session: URLSession = .shared,
                                  bundle: Bundle = .main,
                                  domain: String,
                                  clientId: String,
                                  audience: String,
                                  tokenProvider: any TokenProvider) {
        _shared = Auth0UIComponentsSDKInitializer(audience: ensureHTTPS(audience),
                                    domain: domain,
                                    clientId: clientId,
                                    bundle: bundle,
                                    session: session,
                                    tokenProvider: tokenProvider)
    }

    static func reset() {
        _shared = nil
    }
}

private func ensureHTTPS(_ urlString: String) -> String {
    if urlString.lowercased().hasPrefix("https://") {
        return urlString
    } else {
        return "https://" + urlString
    }
}

private func plistValues(bundle: Bundle) -> (clientId: String, domain: String)? {
    guard let path = bundle.path(forResource: "Auth0", ofType: "plist"),
          let values = NSDictionary(contentsOfFile: path) as? [String: Any] else {
        print("Missing Auth0.plist file with 'ClientId' and 'Domain' entries in main bundle!")
        return nil
    }

    guard let clientId = values["ClientId"] as? String, 
          let domain = values["Domain"] as? String else {
        print("Auth0.plist file is missing 'ClientId' and/or 'Domain' entries!")
        return nil
    }
    
    return (clientId: clientId, domain: domain)
}
