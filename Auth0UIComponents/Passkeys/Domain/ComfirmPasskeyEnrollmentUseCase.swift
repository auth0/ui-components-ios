import Auth0

@available(iOS 16.6, macOS 13.5, visionOS 1.0, *)
struct ConfirmPasskeyEnrollmentRequest {
    let passkey: any NewPasskey
    let token: String
    let domain: String
    let challenge: PasskeyEnrollmentChallenge
}

@available(iOS 16.6, macOS 13.5, visionOS 1.0, *)
protocol ConfirmPasskeyEnrollmentUseCaseable {
    func execute(request: ConfirmPasskeyEnrollmentRequest) async throws -> PasskeyAuthenticationMethod
}

@available(iOS 16.6, macOS 13.5, visionOS 1.0, *)
struct ConfirmPasskeyEnrollmentUseCase: ConfirmPasskeyEnrollmentUseCaseable {
    func execute(request: ConfirmPasskeyEnrollmentRequest) async throws -> PasskeyAuthenticationMethod {
        try await Auth0.myAccount(token: request.token, domain: request.domain)
            .authenticationMethods
            .enroll(passkey: request.passkey, challenge: request.challenge)
            .start()
    }
}
