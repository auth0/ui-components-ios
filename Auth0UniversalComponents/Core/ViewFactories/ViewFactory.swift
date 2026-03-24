import SwiftUI

struct ViewFactory {
    @MainActor
    @ViewBuilder
    static func view(for route: Route, delegate: RefreshAuthDataProtocol?) -> some View {
        switch route {
        case let .totpPushQRScreen(type):
            TOTPPushQRCodeView(viewModel: TOTPPushQRCodeViewModel(type: type,
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
