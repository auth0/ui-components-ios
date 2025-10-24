import Testing
import Foundation
@testable import Auth0UIComponents

@Suite("Get factors use case tests")
struct GetFactorsUseCaseTests {

    @Test func testGetFactorsUseCaseSuccessful() async throws {
        let session: URLSession = {
            let configuration = URLSessionConfiguration.ephemeral
            configuration.protocolClasses = [MockURLProtocol.self]
            return URLSession(configuration: configuration)
        }()
        let useCase = GetFactorsUseCase(session: session)
        
        let mockData = """
                      [
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
                        "type" : "webauthn-roaming",
                        "usage" : [
                         "secondary"
                        ]
                       },
                       {
                        "type" : "webauthn-platform",
                        "usage" : [
                         "primary",
                         "secondary"
                        ]
                       },
                       {
                        "type" : "recovery-code",
                        "usage" : [
                         "secondary"
                        ]
                       }
                      ]
              """.data(using: .utf8)!
        
        MockURLProtocol.resultHandler = { request in
            #expect(request.url?.absoluteString == "https://my-api.com/user/me")
            
            let response = HTTPURLResponse(
                url: request.url!,
                statusCode: 200,
                httpVersion: nil,
                headerFields: nil
            )!
            return (response, mockData)
        }
        
        // Act
        do {
            let result = try await useCase.execute(token: "token")
            #expect(result.isEmpty == false)
        } catch {
            Issue.record("get factors api didn't succeed")
        }
    }

    @Test func testGetFactorsUseCaseFailure() async throws {
        let session: URLSession = {
            let configuration = URLSessionConfiguration.ephemeral
            configuration.protocolClasses = [MockURLProtocol.self]
            return URLSession(configuration: configuration)
        }()
        let useCase = GetFactorsUseCase(session: session)
    }
}
