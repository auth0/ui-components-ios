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

    // MARK: - Tests with Delegate

    class MockRefreshDelegate: RefreshAuthDataProtocol {
        var refreshCalled = false

        func refreshAuthData() {
            refreshCalled = true
        }
    }

    @Test func testInit_withDelegate() async {
        let mockTokenProvider = MockTokenProvider()
        let mockDelegate = MockRefreshDelegate()

        Auth0UIComponentsSDKInitializer.reset()
        Auth0UIComponentsSDKInitializer.initialize(session: makeMockSession(), bundle: .main, domain: mockDomain, clientId: "", audience: "\(mockDomain)/me/", tokenProvider: mockTokenProvider)

        let vm = await SavedAuthenticatorsScreenViewModel(type: .email, authenticationMethods: [], delegate: mockDelegate)
        await MainActor.run {
            #expect(vm.showLoader == true)
            #expect(vm.errorViewModel == nil)
        }
    }

    @Test func testDeletion_callsDelegate() async {
        let mockTokenProvider = MockTokenProvider()
        let mockDelegate = MockRefreshDelegate()
        Auth0UIComponentsSDKInitializer.reset()
        Auth0UIComponentsSDKInitializer.initialize(session: makeMockSession(), bundle: .main, domain: mockDomain, clientId: "", audience: "\(mockDomain)/me/", tokenProvider: mockTokenProvider)

        let getAuthMethodsUseCase = GetAuthMethodsUseCase(session: makeMockSession())
        let deleteAuthMethodsUseCase = DeleteAuthMethodUseCase(session: makeMockSession())
        let viewModel = await SavedAuthenticatorsScreenViewModel(
            getAuthMethodsUseCase: getAuthMethodsUseCase,
            deleteAuthMethodsUseCase: deleteAuthMethodsUseCase,
            type: .sms,
            authenticationMethods: [],
            delegate: mockDelegate
        )

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
                } else {
                    confirmation()
                    return (response, authMethodsNoPhoneMethodsData)
                }
            }

            await viewModel.deleteAuthMethod(authMethod: authMethods[0])

            // Verify delegate was called
            #expect(mockDelegate.refreshCalled == true, "Delegate should be called after successful deletion")
            #expect(viewModel.viewAuthenticationMethods.isEmpty)
        }
    }

    // MARK: - Error Cases

    @Test func testLoadData_handlesAPIError() async throws {
        let mockTokenProvider = MockTokenProvider()
        Auth0UIComponentsSDKInitializer.reset()
        Auth0UIComponentsSDKInitializer.initialize(session: makeMockSession(), bundle: .main, domain: mockDomain, clientId: "", audience: "\(mockDomain)/me/", tokenProvider: mockTokenProvider)

        let viewModel = await SavedAuthenticatorsScreenViewModel(
            getAuthMethodsUseCase: GetAuthMethodsUseCase(session: makeMockSession()),
            type: .sms,
            authenticationMethods: [],
            delegate: nil
        )

        await confirmation(expectedCount: 1) { @MainActor confirmation in
            MockURLProtocol.requestHandler = { request in
                let response = HTTPURLResponse(
                    url: request.url!,
                    statusCode: 500,
                    httpVersion: nil,
                    headerFields: nil
                )!
                confirmation()
                let errorData = """
                {
                    "statusCode": 500,
                    "error": "Internal Server Error",
                    "message": "Server error occurred"
                }
                """.data(using: .utf8)!
                return (response, errorData)
            }

            await viewModel.loadData()

            // Verify error was handled
            #expect(viewModel.showLoader == false, "Loader should be hidden after error")
            #expect(viewModel.errorViewModel != nil, "Error view model should be set on API failure")
        }
    }

    @Test func testLoadData_handlesNetworkError() async throws {
        let mockTokenProvider = MockTokenProvider()
        Auth0UIComponentsSDKInitializer.reset()
        Auth0UIComponentsSDKInitializer.initialize(session: makeMockSession(), bundle: .main, domain: mockDomain, clientId: "", audience: "\(mockDomain)/me/", tokenProvider: mockTokenProvider)

        let viewModel = await SavedAuthenticatorsScreenViewModel(
            getAuthMethodsUseCase: GetAuthMethodsUseCase(session: makeMockSession()),
            type: .sms,
            authenticationMethods: [],
            delegate: nil
        )

        await confirmation(expectedCount: 1) { @MainActor confirmation in
            MockURLProtocol.requestHandler = { request in
                confirmation()
                throw NSError(domain: NSURLErrorDomain, code: NSURLErrorNotConnectedToInternet, userInfo: nil)
            }

            await viewModel.loadData()

            // Verify error was handled
            #expect(viewModel.showLoader == false, "Loader should be hidden after network error")
            #expect(viewModel.errorViewModel != nil, "Error view model should be set on network failure")
        }
    }

    @Test func testDeletion_handlesAPIError() async {
        let mockTokenProvider = MockTokenProvider()
        Auth0UIComponentsSDKInitializer.reset()
        Auth0UIComponentsSDKInitializer.initialize(session: makeMockSession(), bundle: .main, domain: mockDomain, clientId: "", audience: "\(mockDomain)/me/", tokenProvider: mockTokenProvider)

        let getAuthMethodsUseCase = GetAuthMethodsUseCase(session: makeMockSession())
        let deleteAuthMethodsUseCase = DeleteAuthMethodUseCase(session: makeMockSession())
        let viewModel = await SavedAuthenticatorsScreenViewModel(
            getAuthMethodsUseCase: getAuthMethodsUseCase,
            deleteAuthMethodsUseCase: deleteAuthMethodsUseCase,
            type: .sms,
            authenticationMethods: [],
            delegate: nil
        )

        await confirmation(expectedCount: 1) { @MainActor confirmation in
            MockURLProtocol.requestHandler = { request in
                if request.httpMethod == "DELETE" {
                    let response = HTTPURLResponse(
                        url: request.url!,
                        statusCode: 400,
                        httpVersion: nil,
                        headerFields: nil
                    )!
                    confirmation()
                    let errorData = """
                    {
                        "statusCode": 400,
                        "error": "Bad Request",
                        "message": "Cannot delete authentication method"
                    }
                    """.data(using: .utf8)!
                    return (response, errorData)
                } else {
                    let response = HTTPURLResponse(
                        url: request.url!,
                        statusCode: 200,
                        httpVersion: nil,
                        headerFields: nil
                    )!
                    return (response, authMethodsData)
                }
            }

            await viewModel.deleteAuthMethod(authMethod: authMethods[0])

            // Verify error was handled
            #expect(viewModel.showManageAuthSheet == false, "Sheet should be closed after error")
        }
    }

    @Test func testLoadData_withPreloadedMethods() async {
        let mockTokenProvider = MockTokenProvider()
        Auth0UIComponentsSDKInitializer.reset()
        Auth0UIComponentsSDKInitializer.initialize(session: makeMockSession(), bundle: .main, domain: mockDomain, clientId: "", audience: "\(mockDomain)/me/", tokenProvider: mockTokenProvider)

        let viewModel = await SavedAuthenticatorsScreenViewModel(
            type: .sms,
            authenticationMethods: authMethods,
            delegate: nil
        )

        // Verify preloaded methods are available
        await MainActor.run {
            #expect(viewModel.viewAuthenticationMethods.count == 1, "Should have preloaded methods")
        }
    }

    @Test func testLoadData_emptyResponse() async throws {
        let mockTokenProvider = MockTokenProvider()
        Auth0UIComponentsSDKInitializer.reset()
        Auth0UIComponentsSDKInitializer.initialize(session: makeMockSession(), bundle: .main, domain: mockDomain, clientId: "", audience: "\(mockDomain)/me/", tokenProvider: mockTokenProvider)

        let viewModel = await SavedAuthenticatorsScreenViewModel(
            getAuthMethodsUseCase: GetAuthMethodsUseCase(session: makeMockSession()),
            type: .sms,
            authenticationMethods: [],
            delegate: nil
        )

        await confirmation(expectedCount: 1) { @MainActor confirmation in
            MockURLProtocol.requestHandler = { request in
                let response = HTTPURLResponse(
                    url: request.url!,
                    statusCode: 200,
                    httpVersion: nil,
                    headerFields: nil
                )!
                confirmation()
                let emptyData = """
                {
                    "authentication_methods": []
                }
                """.data(using: .utf8)!
                return (response, emptyData)
            }

            await viewModel.loadData()

            // Verify empty list is handled
            #expect(viewModel.viewAuthenticationMethods.isEmpty, "Should have no authentication methods")
            #expect(viewModel.showLoader == false, "Loader should be hidden")
        }
    }

    // MARK: - State Management Tests

    @Test func testManageAuthSheet_stateManagement() async {
        let mockTokenProvider = MockTokenProvider()
        Auth0UIComponentsSDKInitializer.reset()
        Auth0UIComponentsSDKInitializer.initialize(session: makeMockSession(), bundle: .main, domain: mockDomain, clientId: "", audience: "\(mockDomain)/me/", tokenProvider: mockTokenProvider)

        let viewModel = await SavedAuthenticatorsScreenViewModel(
            type: .sms,
            authenticationMethods: authMethods,
            delegate: nil
        )

        // Verify initial state
        await MainActor.run {
            #expect(viewModel.showManageAuthSheet == false, "Sheet should be closed initially")

            // Toggle sheet state
            viewModel.showManageAuthSheet = true
            #expect(viewModel.showManageAuthSheet == true, "Sheet should be open after setting")

            viewModel.showManageAuthSheet = false
            #expect(viewModel.showManageAuthSheet == false, "Sheet should be closed after setting")
        }
    }

    @Test func testViewAuthenticationMethods_initialization() async {
        let mockTokenProvider = MockTokenProvider()
        Auth0UIComponentsSDKInitializer.reset()
        Auth0UIComponentsSDKInitializer.initialize(session: makeMockSession(), bundle: .main, domain: mockDomain, clientId: "", audience: "\(mockDomain)/me/", tokenProvider: mockTokenProvider)

        let smsViewModel = await SavedAuthenticatorsScreenViewModel(type: .sms, authenticationMethods: [], delegate: nil)
        let emailViewModel = await SavedAuthenticatorsScreenViewModel(type: .email, authenticationMethods: [], delegate: nil)
        let totpViewModel = await SavedAuthenticatorsScreenViewModel(type: .totp, authenticationMethods: [], delegate: nil)

        await MainActor.run {
            #expect(smsViewModel.viewAuthenticationMethods.isEmpty, "SMS view model should start with empty methods")
            #expect(emailViewModel.viewAuthenticationMethods.isEmpty, "Email view model should start with empty methods")
            #expect(totpViewModel.viewAuthenticationMethods.isEmpty, "TOTP view model should start with empty methods")
        }
    }

    @Test func testLoadData_populatesAuthenticationMethods() async throws {
        let mockTokenProvider = MockTokenProvider()
        Auth0UIComponentsSDKInitializer.reset()
        Auth0UIComponentsSDKInitializer.initialize(session: makeMockSession(), bundle: .main, domain: mockDomain, clientId: "", audience: "\(mockDomain)/me/", tokenProvider: mockTokenProvider)

        let viewModel = await SavedAuthenticatorsScreenViewModel(
            getAuthMethodsUseCase: GetAuthMethodsUseCase(session: makeMockSession()),
            type: .sms,
            authenticationMethods: [],
            delegate: nil
        )

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

            // Verify methods are loaded
            #expect(viewModel.viewAuthenticationMethods.count == 1, "Should have loaded authentication methods")
            #expect(viewModel.showLoader == false, "Loader should be hidden after load")
        }
    }
}

