import Auth0
import Foundation
@testable import Auth0UIComponents

struct MockAuthMethodsUseCase: UseCase {
    
    var session: URLSession
    
    init(session: URLSession = .shared) {
        self.session = session
    }

    func execute(token: String) async throws -> [AuthenticationMethod] {
        let data = """
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
           "id" : "email|dev_FQAbhQIgug4hpzoR",
           "confirmed" : false,
           "type" : "email",
           "usage" : [
            "secondary"
           ],
           "created_at" : "2025-07-30T12:59:12.016Z"
          },
          {
           "id" : "phone|dev_GbpMh39yHL212CTp",
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
           "id" : "recovery-code|dev_8OW6IA4xxr8RIzmX",
           "confirmed" : true,
           "type" : "recovery-code",
           "usage" : [
            "secondary"
           ],
           "created_at" : "2025-07-30T13:01:09.578Z"
          },
          {
           "id" : "totp|dev_ZDJyYbMAsFt8TvLz",
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
        
        do {
            let authMethods = try JSONDecoder().decode(AuthenticationMethods.self, from: data)
            return authMethods.authenticationMethods
        } catch {
            throw UIComponentError.myAccountError(.init(info: ["error": "parsing error"], statusCode: 100))
        }
    }
}
