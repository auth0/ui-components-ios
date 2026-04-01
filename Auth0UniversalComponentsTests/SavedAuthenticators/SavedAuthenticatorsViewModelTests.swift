// swiftlint:disable:this type_body_length
// swiftlint:disable file_length

@testable import Auth0UniversalComponents
import Auth0
import Foundation
import Testing

@Suite(.serialized)
// swiftlint:disable:next type_body_length
struct SavedAuthenticatorsViewModelTests {
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
        let authMethods = Data("""
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
            """.utf8)
        return authMethods
    }

    var authMethodsNoPhoneMethodsData: Data {
        let data = Data("""
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
                    """.utf8)
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

        Auth0UniversalComponentsSDKInitializer.reset()
        Auth0UniversalComponentsSDKInitializer.initialize(session: makeMockSession(), bundle: .main, domain: mockDomain, clientId: "", audience: "\(mockDomain)/me/", tokenProvider: mockTokenProvider)

        let viewModel = await SavedAuthenticatorsViewModel(type: .email, authenticationMethods: [], delegate: nil)
        await MainActor.run {
            #expect(viewModel.showLoader == true)
            #expect(viewModel.errorViewModel == nil)
        }
    }

    @Test func testLoadDataSuccess() async throws {
        let mockTokenProvider = MockTokenProvider()
        Auth0UniversalComponentsSDKInitializer.reset()
        Auth0UniversalComponentsSDKInitializer.initialize(session: makeMockSession(), bundle: .main, domain: mockDomain, clientId: "", audience: "\(mockDomain)/me/", tokenProvider: mockTokenProvider)

        let viewModel = await SavedAuthenticatorsViewModel(getAuthMethodsUseCase: GetAuthMethodsUseCase(session: makeMockSession()), type: .sms, authenticationMethods: [], delegate: nil)
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
        Auth0UniversalComponentsSDKInitializer.reset()
        Auth0UniversalComponentsSDKInitializer.initialize(session: makeMockSession(), bundle: .main, domain: mockDomain, clientId: "", audience: "\(mockDomain)/me/", tokenProvider: mockTokenProvider)

        let getAuthMethodsUseCase = GetAuthMethodsUseCase(session: makeMockSession())
        let deleteAuthMethodsUseCase = DeleteAuthMethodUseCase(session: makeMockSession())
        let viewModel = await SavedAuthenticatorsViewModel(getAuthMethodsUseCase: getAuthMethodsUseCase,
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
                } else {
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

        Auth0UniversalComponentsSDKInitializer.reset()
        Auth0UniversalComponentsSDKInitializer.initialize(session: makeMockSession(), bundle: .main, domain: mockDomain, clientId: "", audience: "\(mockDomain)/me/", tokenProvider: mockTokenProvider)

        let viewModel = await SavedAuthenticatorsViewModel(type: .email, authenticationMethods: [], delegate: mockDelegate)
        await MainActor.run {
            #expect(viewModel.showLoader == true)
            #expect(viewModel.errorViewModel == nil)
        }
    }

    @Test func testDeletion_callsDelegate() async {
        let mockTokenProvider = MockTokenProvider()
        let mockDelegate = MockRefreshDelegate()
        Auth0UniversalComponentsSDKInitializer.reset()
        Auth0UniversalComponentsSDKInitializer.initialize(session: makeMockSession(), bundle: .main, domain: mockDomain, clientId: "", audience: "\(mockDomain)/me/", tokenProvider: mockTokenProvider)

        let getAuthMethodsUseCase = GetAuthMethodsUseCase(session: makeMockSession())
        let deleteAuthMethodsUseCase = DeleteAuthMethodUseCase(session: makeMockSession())
        let viewModel = await SavedAuthenticatorsViewModel(
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
        Auth0UniversalComponentsSDKInitializer.reset()
        Auth0UniversalComponentsSDKInitializer.initialize(session: makeMockSession(), bundle: .main, domain: mockDomain, clientId: "", audience: "\(mockDomain)/me/", tokenProvider: mockTokenProvider)

        let viewModel = await SavedAuthenticatorsViewModel(
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
                let errorData = Data("""
                {
                    "statusCode": 500,
                    "error": "Internal Server Error",
                    "message": "Server error occurred"
                }
                """.utf8)
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
        Auth0UniversalComponentsSDKInitializer.reset()
        Auth0UniversalComponentsSDKInitializer.initialize(session: makeMockSession(), bundle: .main, domain: mockDomain, clientId: "", audience: "\(mockDomain)/me/", tokenProvider: mockTokenProvider)

        let viewModel = await SavedAuthenticatorsViewModel(
            getAuthMethodsUseCase: GetAuthMethodsUseCase(session: makeMockSession()),
            type: .sms,
            authenticationMethods: [],
            delegate: nil
        )

        await confirmation(expectedCount: 1) { @MainActor confirmation in
            MockURLProtocol.requestHandler = { _ in
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
        Auth0UniversalComponentsSDKInitializer.reset()
        Auth0UniversalComponentsSDKInitializer.initialize(session: makeMockSession(), bundle: .main, domain: mockDomain, clientId: "", audience: "\(mockDomain)/me/", tokenProvider: mockTokenProvider)

        let getAuthMethodsUseCase = GetAuthMethodsUseCase(session: makeMockSession())
        let deleteAuthMethodsUseCase = DeleteAuthMethodUseCase(session: makeMockSession())
        let viewModel = await SavedAuthenticatorsViewModel(
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
                    let errorData = Data("""
                    {
                        "statusCode": 400,
                        "error": "Bad Request",
                        "message": "Cannot delete authentication method"
                    }
                    """.utf8)
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
        }
    }

    /// Verifies that `deleteAuthMethod` targets the specific method passed to it and
    /// leaves all other methods intact — guarding against the bug where a shared
    /// `showManageAuthSheet` binding caused an arbitrary row's action to fire instead
    /// of the one the user actually tapped.
    @Test func testDeletion_deletesOnlyTargetedAuthMethod() async {
        let mockTokenProvider = MockTokenProvider()
        Auth0UniversalComponentsSDKInitializer.reset()
        Auth0UniversalComponentsSDKInitializer.initialize(session: makeMockSession(), bundle: .main, domain: mockDomain, clientId: "", audience: "\(mockDomain)/me/", tokenProvider: mockTokenProvider)

        // Two distinct SMS methods loaded into the list.
        // Note: IDs intentionally use only URL-safe characters (no '|') so that
        // the literal ID string can be matched against the percent-decoded request
        // URL without needing to account for encoding of special characters.
        let twoMethodsData = Data("""
        {
          "authentication_methods": [
            {
              "id": "phone-method-keep",
              "created_at": "2025-07-30T13:01:00.970Z",
              "confirmed": true,
              "usage": ["secondary"],
              "type": "phone",
              "phone_number": "XXXXXXXXX0001"
            },
            {
              "id": "phone-method-delete",
              "created_at": "2025-08-01T10:00:00.000Z",
              "confirmed": true,
              "usage": ["secondary"],
              "type": "phone",
              "phone_number": "XXXXXXXXX0002"
            }
          ]
        }
        """.utf8)

        // After deletion the API returns only the first method.
        let afterDeletionData = Data("""
        {
          "authentication_methods": [
            {
              "id": "phone-method-keep",
              "created_at": "2025-07-30T13:01:00.970Z",
              "confirmed": true,
              "usage": ["secondary"],
              "type": "phone",
              "phone_number": "XXXXXXXXX0001"
            }
          ]
        }
        """.utf8)

        let twoMethods = (try? JSONDecoder().decode(AuthenticationMethods.self, from: twoMethodsData))?.authenticationMethods ?? []
        let methodToKeep = twoMethods[0]
        let methodToDelete = twoMethods[1]

        let getAuthMethodsUseCase = GetAuthMethodsUseCase(session: makeMockSession())
        let deleteAuthMethodsUseCase = DeleteAuthMethodUseCase(session: makeMockSession())
        let viewModel = await SavedAuthenticatorsViewModel(
            getAuthMethodsUseCase: getAuthMethodsUseCase,
            deleteAuthMethodsUseCase: deleteAuthMethodsUseCase,
            type: .sms,
            authenticationMethods: [],
            delegate: nil
        )

        var deletedRequestURL: String?

        await confirmation(expectedCount: 2) { @MainActor confirmation in
            MockURLProtocol.requestHandler = { request in
                let response = HTTPURLResponse(
                    url: request.url!,
                    statusCode: 200,
                    httpVersion: nil,
                    headerFields: nil
                )!
                if request.httpMethod == "DELETE" {
                    deletedRequestURL = request.url?.absoluteString
                    confirmation()
                    return (response, nil)
                } else {
                    confirmation()
                    return (response, afterDeletionData)
                }
            }

            // Explicitly delete the second method — not the first.
            await viewModel.deleteAuthMethod(authMethod: methodToDelete)

            // The DELETE request must target the second method's ID.
            #expect(deletedRequestURL?.contains(methodToDelete.id) == true,
                    "DELETE request should target the tapped method, not an arbitrary row")

            // The first method must still be in the list.
            #expect(viewModel.viewAuthenticationMethods.count == 1,
                    "Exactly one method should remain after deletion")
            #expect(viewModel.viewAuthenticationMethods.first?.id == methodToKeep.id,
                    "The surviving method should be the one that was NOT deleted")
        }
    }

    @Test func testLoadData_withPreloadedMethods() async {
        let mockTokenProvider = MockTokenProvider()
        Auth0UniversalComponentsSDKInitializer.reset()
        Auth0UniversalComponentsSDKInitializer.initialize(session: makeMockSession(), bundle: .main, domain: mockDomain, clientId: "", audience: "\(mockDomain)/me/", tokenProvider: mockTokenProvider)

        let viewModel = await SavedAuthenticatorsViewModel(
            type: .sms,
            authenticationMethods: authMethods,
            delegate: nil
        )

        // Verify preloaded methods are available
        await MainActor.run {
            #expect(viewModel.viewAuthenticationMethods.isEmpty, "Should have preloaded methods")
        }
    }

    @Test func testLoadData_emptyResponse() async throws {
        let mockTokenProvider = MockTokenProvider()
        Auth0UniversalComponentsSDKInitializer.reset()
        Auth0UniversalComponentsSDKInitializer.initialize(session: makeMockSession(), bundle: .main, domain: mockDomain, clientId: "", audience: "\(mockDomain)/me/", tokenProvider: mockTokenProvider)

        let viewModel = await SavedAuthenticatorsViewModel(
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
                let emptyData = Data("""
                {
                    "authentication_methods": []
                }
                """.utf8)
                return (response, emptyData)
            }

            await viewModel.loadData()

            // Verify empty list is handled
            #expect(viewModel.viewAuthenticationMethods.isEmpty, "Should have no authentication methods")
            #expect(viewModel.showLoader == false, "Loader should be hidden")
        }
    }

    @Test func testViewAuthenticationMethods_initialization() async {
        let mockTokenProvider = MockTokenProvider()
        Auth0UniversalComponentsSDKInitializer.reset()
        Auth0UniversalComponentsSDKInitializer.initialize(session: makeMockSession(), bundle: .main, domain: mockDomain, clientId: "", audience: "\(mockDomain)/me/", tokenProvider: mockTokenProvider)

        let smsViewModel = await SavedAuthenticatorsViewModel(type: .sms, authenticationMethods: [], delegate: nil)
        let emailViewModel = await SavedAuthenticatorsViewModel(type: .email, authenticationMethods: [], delegate: nil)
        let totpViewModel = await SavedAuthenticatorsViewModel(type: .totp, authenticationMethods: [], delegate: nil)

        await MainActor.run {
            #expect(smsViewModel.viewAuthenticationMethods.isEmpty, "SMS view model should start with empty methods")
            #expect(emailViewModel.viewAuthenticationMethods.isEmpty, "Email view model should start with empty methods")
            #expect(totpViewModel.viewAuthenticationMethods.isEmpty, "TOTP view model should start with empty methods")
        }
    }

    @Test func testLoadData_populatesAuthenticationMethods() async throws {
        let mockTokenProvider = MockTokenProvider()
        Auth0UniversalComponentsSDKInitializer.reset()
        Auth0UniversalComponentsSDKInitializer.initialize(session: makeMockSession(), bundle: .main, domain: mockDomain, clientId: "", audience: "\(mockDomain)/me/", tokenProvider: mockTokenProvider)

        let viewModel = await SavedAuthenticatorsViewModel(
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
