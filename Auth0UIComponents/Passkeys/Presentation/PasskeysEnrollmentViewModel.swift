import Auth0
import Combine
import AuthenticationServices

@MainActor
final class PasskeysEnrollmentViewModel: NSObject, ObservableObject, ASAuthorizationControllerDelegate {
//    func presentationAnchor(for controller: ASAuthorizationController) -> ASPresentationAnchor {
//       
//    }
    
    private let startPasskeyEnrollmentUseCase: StartPasskeyEnrollmentUseCaseable
    private let confirmPasskeyEnrollmentUseCase: ConfirmPasskeyEnrollmentUseCaseable
    private let dependencies: Auth0UIComponentsSDKInitializer
    private var passkeyChallenge: PasskeyEnrollmentChallenge? = nil

    init(startPasskeyEnrollmentUseCase: StartPasskeyEnrollmentUseCaseable = StartPasskeyEnrollmentUseCase(),
         confirmPasskeyEnrollmentUseCase: ConfirmPasskeyEnrollmentUseCaseable = ConfirmPasskeyEnrollmentUseCase(),
         dependencies: Auth0UIComponentsSDKInitializer = .shared) {
        self.startPasskeyEnrollmentUseCase = startPasskeyEnrollmentUseCase
        self.confirmPasskeyEnrollmentUseCase = confirmPasskeyEnrollmentUseCase
        self.dependencies = dependencies
    }

    func enrollPasskey() {
        if let passkeyChallenge {
            let credentialProvider = ASAuthorizationPlatformPublicKeyCredentialProvider(
                relyingPartyIdentifier: passkeyChallenge.relyingPartyId
            )
            let request = credentialProvider.createCredentialRegistrationRequest(
                challenge: passkeyChallenge.challengeData,
                name: passkeyChallenge.userName,
                userID: passkeyChallenge.userId
            )
            
            let authController = ASAuthorizationController(authorizationRequests: [request])
            authController.delegate = self
            authController.performRequests()
        }
    }

    func startEnrollment() async {
        do {
            let apiCredentials = try await dependencies.tokenProvider.fetchAPICredentials(audience: dependencies.audience, scope: "create:me:authentication_methods")
            passkeyChallenge = try await startPasskeyEnrollmentUseCase.execute(request: StartPasskeyEnrollmentRequest(token: apiCredentials.accessToken, domain: dependencies.domain))
            enrollPasskey()
        } catch {
            print(error)
        }
    }
    
    func authorizationController(controller: ASAuthorizationController, didCompleteWithAuthorization authorization: ASAuthorization) {
        Task {
            switch authorization.credential {
            case let newPasskey as ASAuthorizationPlatformPublicKeyCredentialRegistration:
                if let passkeyChallenge {
                    do {
                        let apiCredentials = try await dependencies.tokenProvider.fetchAPICredentials(audience: dependencies.audience, scope: "create:me:authentication_methods")
                        let passkeyAuthenticationMethod = try await confirmPasskeyEnrollmentUseCase.execute(request: ConfirmPasskeyEnrollmentRequest(passkey: newPasskey, token: apiCredentials.accessToken, domain: dependencies.audience, challenge: passkeyChallenge))
                        print(passkeyAuthenticationMethod)
                    } catch {
                        print(error)
                    }
                }
            default:
                print("Unrecognized credential: \(authorization.credential)")
            }
        }
    }
}
