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

    /// The SDK recognises these by an `error_description` that is the code itself, so the code is never shown.
    @Test(arguments: [("too_many_requests", "too_many_attempts", 429, "Too many attempts. Please try again later."),
                      ("too_many_requests", "too_many_logins", 429, "Too many attempts. Please try again later."),
                      ("access_denied", "too_many_wrong_otp_attempts", 403, "Too many attempts. Please try again later."),
                      ("too_many_requests", "ip_blocked", 429, "Sign-in is temporarily blocked. Please try again later."),
                      ("access_denied", "consent_required", 403, "This sign-in needs consent that can't be given in the app.")])
    func codeOnlyReasons_useOurCopy(_ code: String, _ description: String, _ status: Int, _ copy: String) {
        let error = EmbeddedAuthError(info: ["error": code, "error_description": description], statusCode: status)
        #expect(error.displayMessage == copy)
    }

    @Test(arguments: [("access_denied", "no_eligible_factors"), ("access_denied", "challenge_expired"),
                      ("access_denied", "authorization_rejected"), ("insufficient_authorization", "authorization_pending")])
    func codeOnlyReasons_withTheirOwnHandling_showNoText(_ code: String, _ description: String) {
        let error = EmbeddedAuthError(info: ["error": code, "error_description": description], statusCode: 403)
        #expect(error.displayMessage == nil)
    }

    @Test func noText_fallsBackToCoordinatorMessage() {
        let error = EmbeddedAuthError(info: [:], statusCode: 500)
        #expect(error.displayMessage == nil)
        #expect(Auth0EmbeddedAuthError.requestFailed(message: nil).errorDescription == nil)
    }
}
