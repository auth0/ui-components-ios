@testable import Auth0UIComponents
import Auth0
import Foundation
import Testing

@Suite(.serialized)
struct MyAccountAuthMethodsViewModelTests {
    private let mockToken = "mock_access_token_123"
    private let mockDomain = "test-tenant.auth0.com"
    private func makeMockSession() -> URLSession {
        let config = URLSessionConfiguration.ephemeral
        config.protocolClasses = [MockURLProtocol.self]
        return URLSession(configuration: config)
    }

    func decodeResponse<T: Decodable>(json: Data, locationHeader: String? = nil) throws -> T {
        let decoder = JSONDecoder()
        decoder.userInfo[CodingUserInfoKey(rawValue: "locationHeader")!] = locationHeader
        return try decoder.decode(T.self, from: json)
    }
   
    var authMethodsData: Data {
        let authMethods = """
                  {
                   "authentication_methods" : [
                    {
                     "id" : "password|Njg4OWEwOTc2MWE3ZjIwNzQxN2U4OGYy",
                     "usage" : [
                      "primary"
                     ],
                     "type" : "password",
                     "identity_user_id" : "6889a09761a7f207417e88f2",
                     "created_at" : "2025-07-30T04:33:27.000Z"
                    },
                    {
                     "email" : "nand**********@okta****",
                     "id" : "email|test_FQAbhQIgug4hpzoR",
                     "confirmed" : false,
                     "type" : "email",
                     "usage" : [
                      "secondary"
                     ],
                     "created_at" : "2025-07-30T12:59:12.016Z"
                    },
                    {
                     "id" : "phone|test_GbpMh39yHL212CTp",
                     "created_at" : "2025-07-30T13:01:00.970Z",
                     "preferred_authentication_method" : "sms",
                     "confirmed" : true,
                     "usage" : [
                      "secondary"
                     ],
                     "type" : "phone",
                     "phone_number" : "XXXXXXXXX2046"
                    },
                    {
                     "id" : "recovery-code|test_8OW6IA4xxr8RIzmX",
                     "confirmed" : true,
                     "type" : "recovery-code",
                     "usage" : [
                      "secondary"
                     ],
                     "created_at" : "2025-07-30T13:01:09.578Z"
                    },
                    {
                     "id" : "totp|test_ZDJyYbMAsFt8TvLz",
                     "confirmed" : true,
                     "type" : "totp",
                     "usage" : [
                      "secondary"
                     ],
                     "created_at" : "2025-07-30T13:08:49.508Z"
                    }
                   ]
                  }      
            """.data(using: .utf8)!
        return authMethods
    }
    
    var factorsData: Data {
        let factors = """
            {
            "factors": [
            {
             "type" : "phone",
             "usage" : [
              "secondary"
             ]
            },
            {
             "type" : "push-notification",
             "usage" : [
              "secondary"
             ]
            },
            {
             "type" : "totp",
             "usage" : [
              "secondary"
             ]
            },
            {
             "type" : "email",
             "usage" : [
              "secondary"
             ]
            },
            {
             "type" : "recovery-code",
             "usage" : [
              "secondary"
             ]
            }
            ]}
            """.data(using: .utf8)!
        return factors
    }
    
    var authMethods: [AuthenticationMethod] {
        do {
            let authMethods: AuthenticationMethods = try decodeResponse(json: authMethodsData)
            return authMethods.authenticationMethods
        } catch {
            return []
        }
    }

    var factors: [Factor] {
        do {
            let factors: Factors = try decodeResponse(json: factorsData)
            return factors.factors
        } catch {
            return []
        }
    }


    @Test
    func testInitialState() async {
        Auth0UIComponentsSDKInitializer.reset()
        Auth0UIComponentsSDKInitializer.initialize(session: makeMockSession(), bundle: .main, domain: mockDomain, clientId: "", audience: "\(mockDomain)/me/", tokenProvider: MockTokenProvider())
        let viewModel = await MyAccountAuthMethodsViewModel()
        await MainActor.run {
            #expect(viewModel.errorViewModel == nil)
            #expect(viewModel.viewComponents.isEmpty)
        }
    }
    
    @Test
    func testFetchingOfAuthMethodsSuccess() async {
        let mockTokenProvider = MockTokenProvider()
        Auth0UIComponentsSDKInitializer.reset()
        Auth0UIComponentsSDKInitializer.initialize(session: makeMockSession(), bundle: .main, domain: mockDomain, clientId: "", audience: "\(mockDomain)/me/", tokenProvider: mockTokenProvider)

        let viewModel = await MyAccountAuthMethodsViewModel(factorsUseCase: GetFactorsUseCase(session: makeMockSession()), authMethodsUseCase: GetAuthMethodsUseCase(session: makeMockSession()))
        await confirmation(expectedCount: 2) { @MainActor confirmation in
            MockURLProtocol.requestHandler = { request in
                let response = HTTPURLResponse(
                    url: request.url!,
                    statusCode: 200,
                    httpVersion: nil,
                    headerFields: nil
                )!
                if request.url?.absoluteString.contains("factors") == true {
                    confirmation()
                    return (response, factorsData)
                } else {
                    confirmation()
                    return (response, authMethodsData)
                }
            }
            await viewModel.loadMyAccountAuthViewComponentData()
            #expect(viewModel.viewComponents.count == 7)
        }
    }
}
