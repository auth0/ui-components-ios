import Auth0
import Foundation

/// Protocol for initiating recovery code enrollment.
protocol StartRecoveryCodeEnrollmentUseCaseable {
    var session: URLSession { get }
    func execute(request: StartRecoveryCodeEnrollmentRequest) async throws  -> RecoveryCodeEnrollmentChallenge

}

/// Request parameters for initiating recovery code enrollment.
struct StartRecoveryCodeEnrollmentRequest {
    let token: String
    let domain: String
}


/// Use case for initiating recovery code enrollment and retrieving enrollment challenge.
struct StartRecoveryCodeEnrollmentUseCase: StartRecoveryCodeEnrollmentUseCaseable {
    var session: URLSession
    
    init(session: URLSession = .shared) {
        self.session = session
    }
    
    func execute(request: StartRecoveryCodeEnrollmentRequest) async throws  -> RecoveryCodeEnrollmentChallenge {
        try await Auth0.myAccount(token: request.token, domain: request.domain, session: session)
            .authenticationMethods
            .enrollRecoveryCode()
            .start()
    }
}
