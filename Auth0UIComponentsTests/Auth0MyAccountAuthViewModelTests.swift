import Foundation
import Combine
import Testing
import Auth0
@testable import Auth0UIComponents

@Suite
struct Auth0MyAccountAuthViewModelTests {

    @Test
    func testLoadMyAccountAuthViewComponentDataSuccess() async throws {
        let viewModel = MyAccountAuthMethodsViewModel(refreshToken: "refresh",
                                                      audience: "audience",
                                                      scope: "openid profile",
                                                      factorsUseCase: MockFactorsUseCase(),
                                                      authMethodsUseCase: MockAuthMethodsUseCase(),
                                                      tokenProvider: MockCredentialsManager())
        await viewModel.loadMyAccountAuthViewComponentData()

        #expect(viewModel.viewComponents.isEmpty == false)
    }
}

