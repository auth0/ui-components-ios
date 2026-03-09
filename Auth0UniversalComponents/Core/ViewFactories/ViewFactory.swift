//
//  ViewFactory.swift
//  Auth0UIComponents
//
//  Created by Sudhanshu Vohra on 18/02/26.
//

import SwiftUI

struct ViewFactory {
    @MainActor
    @ViewBuilder
    static func view(for route: Route, delegate: RefreshAuthDataProtocol?) -> some View {
        switch route {
        case let .totpPushQRScreen(type):
            TOTPPushQRCodeView(viewModel: TOTPPushQRCodeViewModel(type: type,
                                                                  delegate: delegate))
        case let .otpScreen(type,
                            emailOrPhoneNumber,
                            totpEnrollmentChallege,
                            phoneEnrollmentChallenge,
                            emailEnrollmentChallenge):
            OTPView(viewModel: OTPViewModel(totpEnrollmentChallenge: totpEnrollmentChallege,
                                            emailEnrollmentChallenge: emailEnrollmentChallenge,
                                            phoneEnrollmentChallenge: phoneEnrollmentChallenge,
                                            type: type,
                                            emailOrPhoneNumber: emailOrPhoneNumber,
                                            delegate: delegate))
        case let .filteredAuthListScreen(type, authMethods):
            SavedAuthenticatorsView(viewModel: SavedAuthenticatorsViewModel(type: type,
                                                                            authenticationMethods: authMethods,
                                                                            delegate: delegate))
        case let .emailPhoneEnrollmentScreen(type):
            EmailPhoneEnrollmentView(viewModel: EmailPhoneEnrollmentViewModel(type: type))
        case .recoveryCodeScreen:
            RecoveryCodeEnrollmentView(viewModel: RecoveryCodeEnrollmentViewModel(delegate: delegate))
        case .enrollPasskeyScreen:
            if #available(iOS 16.6, macOS 13.5, visionOS 1.0, *) {
                PasskeysEnrollmentView(viewModel: PasskeysEnrollmentViewModel(delegate: delegate))
            }
        }
    }
}
