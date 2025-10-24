import Auth0
import SwiftUI
import UIKit
import Combine
import CoreImage.CIFilterBuiltins

@MainActor
final class TOTPPushQRCodeViewModel: ObservableObject {
    private let startTOTPEnrollmentUseCase: StartTOTPEnrollmentUseCaseable
    private let startPushEnrollmentUseCase: StartPushEnrollmentUseCaseable
    private let confirmPushEnrollmentUseCase: ConfirmPushEnrollmentUseCaseable
    private let dependencies: Dependencies
    private let type: AuthMethodType
    private var pushEnrollmentChallenge: PushEnrollmentChallenge?
    private var totpEnrollmentChallenge: TOTPEnrollmentChallenge?

    @Published var qrCodeImage: Image?
    @Published var showLoader: Bool = true
    @Published var manualInputCode: String? = nil
    @Published var errorViewModel: ErrorScreenViewModel? = nil

    init(startTOTPEnrollmentUseCase: StartTOTPEnrollmentUseCaseable = StartTOTPEnrollmentUseCase(),
         startPushEnrolllmentUseCase:StartPushEnrollmentUseCaseable = StartPushEnrollmentUseCase(),
         confirmPushEnrollmentUseCase: ConfirmPushEnrollmentUseCase = ConfirmPushEnrollmentUseCase(),
         type: AuthMethodType,
         dependencies: Dependencies = .shared) {
        self.startTOTPEnrollmentUseCase = startTOTPEnrollmentUseCase
        self.startPushEnrollmentUseCase = startPushEnrolllmentUseCase
        self.confirmPushEnrollmentUseCase = confirmPushEnrollmentUseCase
        self.dependencies = dependencies
        self.type = type
    }

    func fetchEnrollmentChallenge() {
        Task {
            showLoader = true
            errorViewModel = nil
            do {
                let apiCredentials = try await dependencies.tokenProvider.fetchAPICredentials(audience: dependencies.audience, scope: "openid create:me:authentication_methods")
                if type == .pushNotification {
                    pushEnrollmentChallenge = try await startPushEnrollmentUseCase.execute(request: StartPushEnrollmentRequest(token: apiCredentials.accessToken, domain: dependencies.domain))
                } else if type == .totp {
                    totpEnrollmentChallenge = try await startTOTPEnrollmentUseCase.execute(request: StartTOTPEnrollmentRequest(token: apiCredentials.accessToken, domain: dependencies.domain))
                }
                showLoader = false
                setAuthQRCodeImage()
                setAuthManualSetupCode()
            } catch {
                await handle(error: error, scope: "openid create:me:authentication_methods") { [weak self] in
                    self?.fetchEnrollmentChallenge()
                }
            }
        }
    }
    
    func handleContinueButtonTap() {
        Task {
            if let totpEnrollmentChallenge {
                await NavigationStore.shared.push(.otpScreen(type: type, totpEnrollmentChallege: totpEnrollmentChallenge))
            } else {
                confirmEnrollment()
            }
        }
    }
    
    func confirmEnrollment() {
        Task {
            if let pushEnrollmentChallenge {
                do {
                    let apiCredentials = try await dependencies.tokenProvider.fetchAPICredentials(audience: dependencies.audience, scope: "openid create:me:authentication_methods")
                    let _ = try await confirmPushEnrollmentUseCase.execute(request: ConfirmPushEnrollmentRequest(token: apiCredentials.accessToken, domain: dependencies.domain, id: pushEnrollmentChallenge.authenticationId, authSession: pushEnrollmentChallenge.authenticationSession))
                    await NavigationStore.shared.push(.filteredAuthListScreen(type: type, authMethods: []))
                } catch {
                    await handle(error: error, scope: "openid create:me:authentication_methods") { [weak self] in
                        self?.confirmEnrollment()
                    }
                }
            }
        }
    }

    func setAuthQRCodeImage() {
        let context = CIContext()
        let filter = CIFilter.qrCodeGenerator()
        filter.correctionLevel = "H"
        let qrCodeURI: String? = totpEnrollmentChallenge?.authenticatorQRCodeURI ?? pushEnrollmentChallenge?.authenticatorQRCodeURI
        if let qrCodeURI {
            filter.message = Data(qrCodeURI.utf8)
        }

        if let outputImage = filter.outputImage {
            if let cgImage = context.createCGImage(outputImage, from: outputImage.extent) {
                qrCodeImage = Image(decorative: cgImage, scale: 1.0)
            }
        }
    }

    func setAuthManualSetupCode()  {
        if let totpEnrollmentChallenge {
            manualInputCode = totpEnrollmentChallenge.authenticatorManualInputCode
        }
    }
    
    func navigationTitle() -> String {
        if type == .pushNotification  {
            return "Add push notification"
        } else {
            return "Add an Authenticator"
        }
    }

    @MainActor func handle(error: Error,
                           scope: String,
                           retryCallback: @escaping () -> Void) async {
        showLoader = false
        if let error = error as? CredentialsManagerError {
            let uiComponentError = Auth0UIComponentError.handleCredentialsManagerError(error: error)
            if case .mfaRequired = uiComponentError {
                do {
                    let credentials = try await Auth0.webAuth()
                        .audience(dependencies.audience)
                        .scope(scope)
                        .start()
                    dependencies.tokenProvider.store(apiCredentials: APICredentials(from: credentials), for: dependencies.audience)
                    retryCallback()
                } catch  {
                    await handle(error: error,
                                 scope: scope,
                                 retryCallback: retryCallback)
                }
            } else {
                errorViewModel = uiComponentError.errorViewModel(completion: {
                    retryCallback()
                })
            }
        } else if let error  = error as? MyAccountError {
            let uiComponentError = Auth0UIComponentError.handleMyAccountAuthError(error: error)
            errorViewModel = uiComponentError.errorViewModel(completion: {
                retryCallback()
            })
        }
    }
}
