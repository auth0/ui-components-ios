import Foundation

final class MockURLProtocol: URLProtocol {
    nonisolated(unsafe) static var requestHandler: ((URLRequest) throws -> (HTTPURLResponse, Data?))?

    private var capturedHandler: ((URLRequest) throws -> (HTTPURLResponse, Data?))?

    override init(request: URLRequest, cachedResponse: CachedURLResponse?, client: (any URLProtocolClient)?) {
        capturedHandler = Self.requestHandler
        super.init(request: request, cachedResponse: cachedResponse, client: client)
    }

    override static func canInit(with request: URLRequest) -> Bool {
        return true
    }

    override static func canonicalRequest(for request: URLRequest) -> URLRequest {
        return request
    }

    override func startLoading() {
        guard let handler = capturedHandler else {
            client?.urlProtocol(self, didFailWithError: URLError(.unknown))
            return
        }

        do {
            let (response, data) = try handler(request)
            client?.urlProtocol(self, didReceive: response, cacheStoragePolicy: .notAllowed)

            if let data = data {
                client?.urlProtocol(self, didLoad: data)
            }
            client?.urlProtocolDidFinishLoading(self)
        } catch {
            client?.urlProtocol(self, didFailWithError: error)
        }
    }

    override func stopLoading() {}
}
