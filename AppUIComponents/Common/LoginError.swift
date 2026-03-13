import Foundation
import Auth0

struct LoginError: Error, Equatable {
    var message: String
    var failureReason: String?
    
    init(message: String, failureReason: String? = nil) {
        self.message = message
        self.failureReason = failureReason
    }
    
    init(error: Error) {
        self.init(message: error.localizedDescription, failureReason: nil)
    }
    
    init (webAuthError: WebAuthError) {
        self.init(message: webAuthError.message, failureReason: webAuthError.failureReason)
    }
}
