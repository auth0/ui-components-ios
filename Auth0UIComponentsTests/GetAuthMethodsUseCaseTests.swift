import Testing
import Foundation
@testable import Auth0UIComponents

@Suite("Get auth methods use case tests")
struct GetAuthMethodsUseCaseTests {
    @Test
    func testGetAuthMethodSuccess() async throws {
        let session: URLSession = {
            let configuration = URLSessionConfiguration.ephemeral
            configuration.protocolClasses = [MockURLProtocol.self]
            return URLSession(configuration: configuration)
        }()
        let useCase = GetAuthMethodsUseCase(session: session)
    }

    @Test
    func testGetAuthMethodsFailure() async throws {
        let session: URLSession = {
            let configuration = URLSessionConfiguration.ephemeral
            configuration.protocolClasses = [MockURLProtocol.self]
            return URLSession(configuration: configuration)
        }()
        let useCase = GetAuthMethodsUseCase(session: session)
    }
}
