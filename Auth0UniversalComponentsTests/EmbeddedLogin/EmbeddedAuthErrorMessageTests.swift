@testable import Auth0UniversalComponents
import Auth0
import Foundation
import Testing

@Suite
struct EmbeddedAuthErrorMessageTests {

    @Test func cause_showsOnlyTheCauseText() {
        let cause = URLError(.notConnectedToInternet)
        let error = EmbeddedAuthError(info: ["cause": cause], statusCode: 0)
        #expect(error.displayMessage == cause.localizedDescription)
        #expect(error.displayMessage?.contains("CAUSE") == false)
    }

    @Test func noCause_usesServerDescription() {
        let error = EmbeddedAuthError(info: ["error": "invalid_request", "error_description": "Connection is disabled."],
                                      statusCode: 400)
        #expect(error.displayMessage == "Connection is disabled.")
    }

    @Test func noText_fallsBackToCoordinatorMessage() {
        let error = EmbeddedAuthError(info: [:], statusCode: 500)
        #expect(error.displayMessage == nil)
        #expect(Auth0EmbeddedAuthError.requestFailed(message: nil).errorDescription == nil)
    }
}
