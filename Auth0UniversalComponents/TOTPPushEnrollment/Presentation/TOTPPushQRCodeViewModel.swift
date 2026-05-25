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
    private let dependencies: Auth0UniversalComponentsSDKInitializer
    private let type: AuthMethodType
    private var pushEnrollmentChallenge: PushEnrollmentChallenge?
    private var totpEnrollmentChallenge: TOTPEnrollmentChallenge?
    private weak var delegate: RefreshAuthDataProtocol?
    private let errorHandler = ErrorHandler()
    @Published var qrCodeURI: String?
    @Published var showLoader: Bool = true
    @Published var manualInputCode: String?
    @Published var showManualCodeText: Bool = false
    @Published var errorViewModel: ErrorScreenViewModel?
    @Published var apiCallInProgress: Bool = false
    @Published var toast: Toast?
    @Published var navigationRoute: Route?

    init(startTOTPEnrollmentUseCase: StartTOTPEnrollmentUseCaseable = StartTOTPEnrollmentUseCase(),
         startPushEnrollmentUseCase: StartPushEnrollmentUseCaseable = StartPushEnrollmentUseCase(),
         confirmPushEnrollmentUseCase: ConfirmPushEnrollmentUseCase = ConfirmPushEnrollmentUseCase(),
         type: AuthMethodType,
         dependencies: Auth0UniversalComponentsSDKInitializer = .shared,
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
        TelemetryManager.shared.trackScreenView("totp_push_qr", properties: ["factor_type": type.rawValue])
        TelemetryManager.shared.trackFlow("enrollment_started", factorType: type.rawValue)
        let startTime = CFAbsoluteTimeGetCurrent()
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
                let durationMs = Int((CFAbsoluteTimeGetCurrent() - startTime) * 1000)
                TelemetryManager.shared.trackApiCall("start_push_enrollment", durationMs: durationMs, status: .success)
            } else if type == .totp {
                totpEnrollmentChallenge = try await startTOTPEnrollmentUseCase
                    .execute(
                        request: StartTOTPEnrollmentRequest(
                            token: apiCredentials.accessToken,
                            domain: dependencies.domain
                        )
                    )
                let durationMs = Int((CFAbsoluteTimeGetCurrent() - startTime) * 1000)
                TelemetryManager.shared.trackApiCall("start_totp_enrollment", durationMs: durationMs, status: .success)
            }
            showLoader = false
            setAuthQRCodeImage()
            setAuthManualSetupCode()
        } catch {
            let durationMs = Int((CFAbsoluteTimeGetCurrent() - startTime) * 1000)
            let apiName = type == .pushNotification ? "start_push_enrollment" : "start_totp_enrollment"
            TelemetryManager.shared.trackApiCall(apiName, durationMs: durationMs, status: .failure, errorType: String(describing: Swift.type(of: error)))
            TelemetryManager.shared.trackFlow("enrollment_failed", factorType: type.rawValue, status: .failure)
            await handle(error: error, scope: "openid create:me:authentication_methods") { [weak self] in
                Task {
                    await self?.fetchEnrollmentChallenge()
                }
            }
        }
    }

    func handleContinueButtonTap() async {
        if let totpEnrollmentChallenge {
            navigationRoute = .otpScreen(type: type, totpEnrollmentChallege: totpEnrollmentChallenge)
        } else {
            apiCallInProgress = true
            await confirmEnrollment()
        }
    }

    private func confirmEnrollment() async {
        if let pushEnrollmentChallenge {
            let startTime = CFAbsoluteTimeGetCurrent()
            do {
                let apiCredentials = try await dependencies.tokenProvider.fetchAPICredentials(
                    audience: dependencies.audience,
                    scope: "openid create:me:authentication_methods"
                )
                let confirmPushEnrollmentRequest = ConfirmPushEnrollmentRequest(
                    token: apiCredentials.accessToken,
                    domain: dependencies.domain,
                    id: pushEnrollmentChallenge.authenticationId,
                    authSession: pushEnrollmentChallenge.authenticationSession
                )
                _ = try await confirmPushEnrollmentUseCase.execute(
                    request: confirmPushEnrollmentRequest
                )
                let durationMs = Int((CFAbsoluteTimeGetCurrent() - startTime) * 1000)
                TelemetryManager.shared.trackApiCall("confirm_push_enrollment", durationMs: durationMs, status: .success)
                TelemetryManager.shared.trackFlow("enrollment_completed", factorType: type.rawValue, status: .success)
                delegate?.refreshAuthData()
                apiCallInProgress = false
                navigationRoute = .filteredAuthListScreen(type: type, authMethods: [], isPostEnrollment: true)
            } catch {
                let durationMs = Int((CFAbsoluteTimeGetCurrent() - startTime) * 1000)
                TelemetryManager.shared.trackApiCall("confirm_push_enrollment", durationMs: durationMs, status: .failure, errorType: String(describing: Swift.type(of: error)))
                TelemetryManager.shared.trackFlow("enrollment_failed", factorType: type.rawValue, status: .failure)
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
        qrCodeURI = totpEnrollmentChallenge?.authenticatorQRCodeURI ?? pushEnrollmentChallenge?.authenticatorQRCodeURI
    }

    private func setAuthManualSetupCode() {
        if totpEnrollmentChallenge.isNotNil || pushEnrollmentChallenge.isNotNil {
            let manualCode: String? = totpEnrollmentChallenge?.authenticatorManualInputCode ?? pushEnrollmentChallenge?.authenticatorQRCodeURI
            manualInputCode = manualCode
            showManualCodeText = totpEnrollmentChallenge.isNotNil
        }
    }

    func navigationTitle() -> String {
        if type == .pushNotification {
            return "Add push notification"
        } else {
            return "Add an Authenticator"
        }
    }

    func handle(error: Error, scope: String, retryCallback: @escaping () -> Void) async {
        await errorHandler.handle(error: error, scope: scope, handler: self, retryCallback: retryCallback)
    }
}
