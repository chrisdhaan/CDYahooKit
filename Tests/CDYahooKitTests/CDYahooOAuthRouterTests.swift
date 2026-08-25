//
//  CDYahooOAuthRouterTests.swift
//  CDYahooKitTests
//

import Foundation
import Testing
@testable import CDYahooKit

@Suite("CDYahooOAuthRouter")
struct CDYahooOAuthRouterTests {

    @Test("authorize builds a POST to the token endpoint with Basic auth and a form-encoded body")
    func authorizeBuildsCorrectRequest() throws {
        let request = try CDYahooOAuthRouter.authorize(code: "abc123", redirectUrl: "myapp://callback", codeVerifier: "verifier-value")
            .asURLRequest(clientId: "client-id", clientSecret: "client-secret")

        #expect(request.url?.absoluteString == "https://api.login.yahoo.com/oauth2/get_token")
        #expect(request.httpMethod == "POST")
        #expect(request.value(forHTTPHeaderField: "Content-Type") == "application/x-www-form-urlencoded")

        let expectedCredentials = Data("client-id:client-secret".utf8).base64EncodedString()
        #expect(request.value(forHTTPHeaderField: "Authorization") == "Basic \(expectedCredentials)")

        let bodyString = String(data: try #require(request.httpBody), encoding: .utf8) ?? ""
        #expect(bodyString.contains("grant_type=authorization_code"))
        #expect(bodyString.contains("code=abc123"))
        #expect(bodyString.contains("code_verifier=verifier-value"))
        #expect(bodyString.contains("redirect_uri=myapp://callback"))
    }

    @Test("refresh builds a POST with grant_type=refresh_token")
    func refreshBuildsCorrectRequest() throws {
        let request = try CDYahooOAuthRouter.refresh(refreshToken: "refresh-abc", redirectUrl: "myapp://callback")
            .asURLRequest(clientId: "client-id", clientSecret: "client-secret")

        let bodyString = String(data: try #require(request.httpBody), encoding: .utf8) ?? ""
        #expect(bodyString.contains("grant_type=refresh_token"))
        #expect(bodyString.contains("refresh_token=refresh-abc"))
    }
}
