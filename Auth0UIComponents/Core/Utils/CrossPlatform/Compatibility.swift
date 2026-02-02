import UIKit

// Method to open external URL based on platform
public func openExternalLink(_ url: URL) {
    #if os(iOS)
        UIApplication.shared.open(url)
    #elseif os(macOS)
        NSWorkspace.shared.open(url)
    #endif
}

// Method to validate the URL String
func validate(urlString: String) throws -> URL {
    guard let url = URL(string: urlString) else {
        // Returns the standard Foundation error for a malformed URL
        throw URLError(.badURL)
    }
    return url
}
