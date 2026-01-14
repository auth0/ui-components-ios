import SwiftUI
import Combine

public struct MyAccountAuthMethodsView: View {
    @StateObject private var navigationStore = NavigationStore.shared
    @ObservedObject private var viewModel: MyAccountAuthMethodsViewModel

    public init() {
        self.viewModel = MyAccountAuthMethodsViewModel()
    }

    public var body: some View {
        NavigationStack(path: $navigationStore.path) {
            ZStack {
                if viewModel.showLoader {
                    ProgressView()
                        .progressViewStyle(CircularProgressViewStyle())
                        .tint(Color("3C3C43", bundle: ResourceBundle.default))
                        .scaleEffect(1.5)
                        .frame(width: 50, height: 50)
                }
                else if let errorViewModel = viewModel.errorViewModel {
                    ErrorScreen(viewModel: errorViewModel)
                        .padding()
                }
                else {
                    ScrollView(showsIndicators: false) {
                        LazyVStack(alignment: .leading) {
                            ForEach(viewModel.viewComponents, id: \.self) { component in
                                authMethodView(component)
                            }
                        }.padding(.all, 16)
                    }
                }
            }
            .navigationTitle(Text("Login & Security"))
            #if !os(macOS)
                .navigationBarTitleDisplayMode(.inline)
            #endif
                .navigationDestination(for: Route.self) { route in
                    handleRoute(route: route)
                }
        }
        .onAppear {
            Task {
                await viewModel.loadMyAccountAuthViewComponentData()
            }
        }.onReceive(navigationStore.popDataRefreshPublisher) { _ in
            Task {
                await viewModel.loadMyAccountAuthViewComponentData()
            }
        }.onReceive(refreshAuthComponents.receive(on: DispatchQueue.main).eraseToAnyPublisher()) { _ in
            viewModel.resetDataBeforeRefresing()
        }
    }

    @ViewBuilder
    private func authMethodView(_ component: MyAccountAuthViewComponentData) -> some View {
        switch component {
        case .title(let text):
            Text(text)
                .foregroundStyle(Color("000000", bundle: ResourceBundle.default))
                .font(.system(size: 20, weight: .semibold))
        case .subtitle(let text):
            Text(text)
                .foregroundStyle(Color("606060", bundle: ResourceBundle.default))
                .font(.system(size: 14, weight: .regular))
        case .additionalVerificationMethods(let viewModel):
            MyAccountAuthMethodView(viewModel: viewModel)
        case .emptyFactors:
            EmptyFactorsView()
        }
    }

    @ViewBuilder
    private func handleRoute(route: Route) -> some View {
        switch route {
        case let .totpPushQRScreen(type):
            TOTPPushQRCodeView(viewModel: TOTPPushQRCodeViewModel(type: type))
        case let .otpScreen(type, emailOrPhoneNumber, totpEnrollmentChallege, phoneEnrollmentChallenge, emailEnrollmentChallenge):
            OTPView(viewModel: OTPViewModel(
                totpEnrollmentChallenge: totpEnrollmentChallege,
                emailEnrollmentChallenge: emailEnrollmentChallenge,
                phoneEnrollmentChallenge: phoneEnrollmentChallenge,
                type: type,
                emailOrPhoneNumber: emailOrPhoneNumber
            ))
        case let .filteredAuthListScreen(type, authMethods):
            SavedAuthenticatorsScreen(viewModel: SavedAuthenticatorsScreenViewModel(
                type: type,
                authenticationMethods: authMethods
            ))
        case let .emailPhoneEnrollmentScreen(type):
            EmailPhoneEnrollmentView(viewModel: EmailPhoneEnrollmentViewModel(type: type))
        case .recoveryCodeScreen:
            RecoveryCodeEnrollmentView(viewModel: RecoveryCodeEnrollmentViewModel())
        }
    }
}
