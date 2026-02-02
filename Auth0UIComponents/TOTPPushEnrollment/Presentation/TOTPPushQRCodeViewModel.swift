import Auth0
import SwiftUI
import Combine
import CoreImage.CIFilterBuiltins
#if canImport(UIKit)
import UIKit
#endif

#if canImport(AppKit)
import AppKit
#endif

/// View model for displaying QR codes for TOTP and push notification enrollment.
///
/// Manages the generation and display of QR codes for authenticator app setup,
/// as well as push notification enrollment. Provides manual entry codes as a fallback
/// for users unable to scan QR codes.
@MainActor
final class TOTPPushQRCodeViewModel: ObservableObject, ErrorViewModelHandler {
    private let startTOTPEnrollmentUseCase: StartTOTPEnrollmentUseCaseable
    private let startPushEnrollmentUseCase: StartPushEnrollmentUseCaseable
    private let confirmPushEnrollmentUseCase: ConfirmPushEnrollmentUseCaseable
    private let dependencies: Auth0UIComponentsSDKInitializer
    private let type: AuthMethodType
    private var pushEnrollmentChallenge: PushEnrollmentChallenge?
    private var totpEnrollmentChallenge: TOTPEnrollmentChallenge?
    private weak var delegate: RefreshAuthDataProtocol?
    private let errorHandler = ErrorHandler()
    @Published var qrCodeImage: Image?
    @Published var showLoader: Bool = true
    @Published var manualInputCode: String? = nil
    @Published var errorViewModel: ErrorScreenViewModel? = nil
    @Published var apiCallInProgress: Bool = false
    @Published var toast: Toast? = nil

    init(startTOTPEnrollmentUseCase: StartTOTPEnrollmentUseCaseable = StartTOTPEnrollmentUseCase(),
         startPushEnrollmentUseCase: StartPushEnrollmentUseCaseable = StartPushEnrollmentUseCase(),
         confirmPushEnrollmentUseCase: ConfirmPushEnrollmentUseCase = ConfirmPushEnrollmentUseCase(),
         type: AuthMethodType,
         dependencies: Auth0UIComponentsSDKInitializer = .shared,
         delegate: RefreshAuthDataProtocol? = nil) {
        self.startTOTPEnrollmentUseCase = startTOTPEnrollmentUseCase
        self.startPushEnrollmentUseCase = startPushEnrollmentUseCase
        self.confirmPushEnrollmentUseCase = confirmPushEnrollmentUseCase
        self.dependencies = dependencies
        self.type = type
        self.delegate = delegate
    }

    func fetchEnrollmentChallenge() async {
        showLoader = true
        errorViewModel = nil
        do {
            let apiCredentials = try await dependencies.tokenProvider.fetchAPICredentials(
                audience: dependencies.audience,
                scope: "openid create:me:authentication_methods"
            )
            if type == .pushNotification {
                pushEnrollmentChallenge = try await startPushEnrollmentUseCase
                    .execute(
                        request: StartPushEnrollmentRequest(
                            token: apiCredentials.accessToken,
                            domain: dependencies.domain
                        )
                    )
            } else if type == .totp {
                totpEnrollmentChallenge = try await startTOTPEnrollmentUseCase
                    .execute(
                        request: StartTOTPEnrollmentRequest(
                            token: apiCredentials.accessToken,
                            domain: dependencies.domain
                        )
                    )
            }
            showLoader = false
            setAuthQRCodeImage()
            setAuthManualSetupCode()
        } catch {
            await handle(error: error, scope: "openid create:me:authentication_methods") { [weak self] in
                Task {
                    await self?.fetchEnrollmentChallenge()
                }
            }
        }
    }

    func handleContinueButtonTap() async {
        if let totpEnrollmentChallenge {
            await NavigationStore.shared.push(.otpScreen(type: type, totpEnrollmentChallege: totpEnrollmentChallenge))
        } else {
            apiCallInProgress = true
            await confirmEnrollment()
        }
    }

    private func confirmEnrollment() async {
        if let pushEnrollmentChallenge {
            do {
                let apiCredentials = try await dependencies.tokenProvider.fetchAPICredentials(audience: dependencies.audience, scope: "openid create:me:authentication_methods")
                let confirmPushEnrollmentRequest = ConfirmPushEnrollmentRequest(token: apiCredentials.accessToken,
                                                                                domain: dependencies.domain,
                                                                                id: pushEnrollmentChallenge.authenticationId,
                                                                                authSession: pushEnrollmentChallenge.authenticationSession)
                let _ = try await confirmPushEnrollmentUseCase.execute(request: confirmPushEnrollmentRequest)
                delegate?.refreshAuthData()
                apiCallInProgress = false
                await NavigationStore.shared.push(.filteredAuthListScreen(type: type, authMethods: []))
            } catch {
                apiCallInProgress = false
                await handle(error: error, scope: "openid create:me:authentication_methods") { [weak self] in
                    Task {
                        await self?.confirmEnrollment()
                    }
                }
            }
        }
    }

    private func setAuthQRCodeImage() {
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

    private func setAuthManualSetupCode()  {
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

    func handle(error: Error, scope: String, retryCallback: @escaping () -> Void) async {
        await errorHandler.handle(error: error, scope: scope, handler: self, retryCallback: retryCallback)
    }
}
