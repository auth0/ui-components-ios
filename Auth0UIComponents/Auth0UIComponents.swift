import SwiftUI
import Auth0

@MainActor
public func myAcountAuthView(_ session: URLSession = .shared,
                             refreshToken: String,
                             domain: String? = nil,
                             audience: String? = nil,
                             tokenProvider: any TokenProvider) -> some View {
    let config = plistValues(bundle: Bundle.main)!
    Dependencies.initialize(audience: audience ?? config.domain.appending("/me/"),
                            domain: domain ?? config.domain,
                            tokenProvider: tokenProvider)
    return MyAccountAuthMethodsView(viewModel: MyAccountAuthMethodsViewModel(session: session))
}

func plistValues(bundle: Bundle) -> (clientId: String, domain: String)? {
    guard let path = bundle.path(forResource: "Auth0", ofType: "plist"),
          let values = NSDictionary(contentsOfFile: path) as? [String: Any] else {
        print("Missing Auth0.plist file with 'ClientId' and 'Domain' entries in main bundle!")
        return nil
    }
    
    guard let clientId = values["ClientId"] as? String, let domain = values["Domain"] as? String else {
        print("Auth0.plist file at \(path) is missing 'ClientId' and/or 'Domain' entries!")
        print("File currently has the following entries: \(values)")
        return nil
    }
    return (clientId: clientId, domain: domain)
}
