import Auth0

@available(iOS 16.6, macOS 13.5, visionOS 1.0, *)
struct StartPasskeyEnrollmentRequest {
    let token: String
    let domain: String
    let userIdentityId: String? = nil
    let connection: String? = nil
}

@available(iOS 16.6, macOS 13.5, visionOS 1.0, *)
protocol StartPasskeyEnrollmentUseCaseable {
    func execute(request: StartPasskeyEnrollmentRequest) async throws -> PasskeyEnrollmentChallenge
}

@available(iOS 16.6, macOS 13.5, visionOS 1.0, *)
struct StartPasskeyEnrollmentUseCase: StartPasskeyEnrollmentUseCaseable {
    func execute(request: StartPasskeyEnrollmentRequest) async throws -> PasskeyEnrollmentChallenge {
        try await Auth0.myAccount(token: request.token, domain: request.domain)
            .authenticationMethods
            .passkeyEnrollmentChallenge()
            .start()
    }
}
