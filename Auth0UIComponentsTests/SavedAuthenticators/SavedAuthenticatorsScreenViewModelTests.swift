@testable import Auth0UIComponents
import Auth0
import Foundation
import Testing

@Suite(.serialized)
struct SavedAuthenticatorsScreenViewModelTests {
    private let mockToken = "mock_access_token_123"
    private let mockDomain = "test-tenant.auth0.com"
    private func makeMockSession() -> URLSession {
        let config = URLSessionConfiguration.ephemeral
        config.protocolClasses = [MockURLProtocol.self]
        return URLSession(configuration: config)
    }

    func decodeResponse<T: Decodable>(json: Data) throws -> T {
        let decoder = JSONDecoder()
        return try decoder.decode(T.self, from: json)
    }
    
    var authMethodsData: Data {
        let authMethods = """
                        {
                          "authentication_methods" : [
                            {
                               "id" : "phone|test_GbpMh39yHL212CTp",
                               "created_at" : "2025-07-30T13:01:00.970Z",
                               "preferred_authentication_method" : "sms",
                               "confirmed" : true,
                               "usage" : [
                                "secondary"
                               ],
                               "type" : "phone",
                               "phone_number" : "XXXXXXXXX1234"
                              }
            ]
                        }
            """.data(using: .utf8)!
        return authMethods
    }

    var authMethodsNoPhoneMethodsData: Data {
        let data =  """
                                {
                                  "authentication_methods" : [
                                    {
                                     "id" : "push-notification|dev_hlj1t7rBdvHIhTvn",
                                     "confirmed" : true,
                                     "type" : "push-notification",
                                     "usage" : [
                                      "secondary"
                                     ],
                                     "created_at" : "2025-11-07T05:26:32.596Z"
                                    }
                    ]
                                }
                    """.data(using: .utf8)!
        return data
    }
 
    var authMethods: [AuthenticationMethod] {
        do {
            let authMethods: AuthenticationMethods = try decodeResponse(json: authMethodsData)
            return authMethods.authenticationMethods
        } catch {
            return []
        }
    }

    var authMethodsNoPhoneMethods: [AuthenticationMethod] {
        do {
            let authMethods: AuthenticationMethods = try decodeResponse(json: authMethodsData)
            return authMethods.authenticationMethods
        } catch {
            return []
        }
    }

    @Test func testInit_initialState() async {
        let mockTokenProvider = MockTokenProvider()

        Auth0UIComponentsSDKInitializer.reset()
        Auth0UIComponentsSDKInitializer.initialize(session: makeMockSession(), bundle: .main, domain: mockDomain, clientId: "", audience: "\(mockDomain)/me/", tokenProvider: mockTokenProvider)

        let vm = await SavedAuthenticatorsScreenViewModel(type: .email, authenticationMethods: [], delegate: nil)
        await MainActor.run {
            #expect(vm.showLoader == true)
            #expect(vm.errorViewModel == nil)
            #expect(vm.showManageAuthSheet == false)
        }
    }
    
    @Test func testLoadDataSuccess() async throws {
        let mockTokenProvider = MockTokenProvider()
        Auth0UIComponentsSDKInitializer.reset()
        Auth0UIComponentsSDKInitializer.initialize(session: makeMockSession(), bundle: .main, domain: mockDomain, clientId: "", audience: "\(mockDomain)/me/", tokenProvider: mockTokenProvider)

        let viewModel = await SavedAuthenticatorsScreenViewModel(getAuthMethodsUseCase: GetAuthMethodsUseCase(session: makeMockSession()), type: .sms, authenticationMethods: [], delegate: nil)
        await confirmation(expectedCount: 1) { @MainActor confirmation in
            MockURLProtocol.requestHandler = { request in
                let response = HTTPURLResponse(
                    url: request.url!,
                    statusCode: 200,
                    httpVersion: nil,
                    headerFields: nil
                )!
                confirmation()
                return (response, authMethodsData)
            }
            await viewModel.loadData()
            #expect(viewModel.viewAuthenticationMethods.count == 1)
        }
    }

    @Test
    func testDeletionSuccess() async {
        let mockTokenProvider = MockTokenProvider()
        Auth0UIComponentsSDKInitializer.reset()
        Auth0UIComponentsSDKInitializer.initialize(session: makeMockSession(), bundle: .main, domain: mockDomain, clientId: "", audience: "\(mockDomain)/me/", tokenProvider: mockTokenProvider)

        let getAuthMethodsUseCase = GetAuthMethodsUseCase(session: makeMockSession())
        let deleteAuthMethodsUseCase = DeleteAuthMethodUseCase(session: makeMockSession())
        let viewModel = await SavedAuthenticatorsScreenViewModel(getAuthMethodsUseCase: getAuthMethodsUseCase,
                                                                 deleteAuthMethodsUseCase: deleteAuthMethodsUseCase,
                                                                 type: .sms,
                                                                 authenticationMethods: [], delegate: nil)
        await confirmation(expectedCount: 2) { @MainActor confirmation in
            MockURLProtocol.requestHandler = { request in
                let response = HTTPURLResponse(
                    url: request.url!,
                    statusCode: 200,
                    httpVersion: nil,
                    headerFields: nil
                )!
                if request.httpMethod == "DELETE" {
                    confirmation()
                    return (response, nil)
                }  else {
                    confirmation()
                    return (response, authMethodsNoPhoneMethodsData)
                }
            }
            await viewModel.deleteAuthMethod(authMethod: authMethods[0])
            #expect(viewModel.viewAuthenticationMethods.isEmpty)
        }
    }
}

