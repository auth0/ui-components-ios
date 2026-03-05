import Auth0

struct MockUserAgent: WebAuthUserAgent {
    func start() {
    }

    func finish(with result: Auth0.WebAuthResult<Void>) {
        
    }
}
