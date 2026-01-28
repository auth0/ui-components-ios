import Auth0

struct StartPasskeyEnrollmentRequest {
    let token: String
    let domain: String
    let userIdentityId: String? = nil
    let connection: String? = nil
}

protocol StartPasskeyEnrollmentUseCaseable {
    func execute(request: StartPasskeyEnrollmentRequest) async throws -> PasskeyEnrollmentChallenge
}

struct StartPasskeyEnrollmentUseCase: StartPasskeyEnrollmentUseCaseable {
    func execute(request: StartPasskeyEnrollmentRequest) async throws -> PasskeyEnrollmentChallenge {
        try await Auth0.myAccount(token: request.token, domain: request.domain)
            .authenticationMethods
            .passkeyEnrollmentChallenge()
            .start()
        
    }
}
