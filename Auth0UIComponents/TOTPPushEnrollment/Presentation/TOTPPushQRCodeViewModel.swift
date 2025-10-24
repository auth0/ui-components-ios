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

    func fetchEnrollmentChallenge() async {
        showLoader = true
        do {
            let apiCredentials = try await dependencies.tokenProvider.fetchAPICredentials(audience: dependencies.audience, scope: "create:me:authentication_methods")
            if type == .pushNotification {
                pushEnrollmentChallenge = try await startPushEnrollmentUseCase.execute(request: StartPushEnrollmentRequest(token: apiCredentials.accessToken, domain: dependencies.domain))
            } else if type == .totp {
                totpEnrollmentChallenge = try await startTOTPEnrollmentUseCase.execute(request: StartTOTPEnrollmentRequest(token: apiCredentials.accessToken, domain: dependencies.domain))
            }
            showLoader = false
            setAuthQRCodeImage()
            setAuthManualSetupCode()
        } catch {
            showLoader = false
            errorViewModel = ErrorScreenViewModel(title: "Something went wrong", subTitle: "", buttonTitle: "", buttonClick: { [weak self] in
                Task {
                    self?.errorViewModel = nil
                    await self?.fetchEnrollmentChallenge()
                }
            })
        }
    }
    
    func handleContinueButtonTap() {
        Task {
            if let totpEnrollmentChallenge {
                await NavigationStore.shared.push(.otpScreen(type: type, totpEnrollmentChallege: totpEnrollmentChallenge))
            } else {
                await confirmEnrollment()
            }
        }
    }
    
    func confirmEnrollment() async {
        if let pushEnrollmentChallenge {
            do {
                let apiCredentials = try await dependencies.tokenProvider.fetchAPICredentials(audience: dependencies.audience, scope: "create:me:authentication_methods")
                let _ = try await confirmPushEnrollmentUseCase.execute(request: ConfirmPushEnrollmentRequest(token: apiCredentials.accessToken, domain: dependencies.domain, id: pushEnrollmentChallenge.authenticationId, authSession: pushEnrollmentChallenge.authenticationSession))
                await NavigationStore.shared.push(.filteredAuthListScreen(type: type, authMethods: []))
            } catch {
                errorViewModel = ErrorScreenViewModel(title: "Something went wrong", subTitle: "", buttonTitle: "", buttonClick: { [weak self] in
                    Task {
                        self?.errorViewModel = nil
                        // TOOO: hide button loader
                    }
                })
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
}
