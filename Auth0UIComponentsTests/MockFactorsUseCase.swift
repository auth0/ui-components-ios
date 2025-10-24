import Auth0
import Foundation
@testable import Auth0UIComponents

struct MockFactorsUseCase: UseCase {
    
    var session: URLSession
    
    init(session: URLSession = .shared) {
        self.session = session
    }

    func execute(token: String) async throws -> [Factor] {
        let data = """
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
        
        do {
            let factorsResponse = try JSONDecoder().decode(Factors.self, from: data)
            return factorsResponse.factors
        } catch {
            throw UIComponentError.myAccountError(.init(info: ["error": "parsing error"], statusCode: 100))
        }
    }
    
}
