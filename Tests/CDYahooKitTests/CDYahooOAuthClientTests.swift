//
//  CDYahooOAuthClientTests.swift
//  CDYahooKitTests
//

import Foundation
import Testing
@testable import CDYahooKit
import CDYahooKitTesting

// .serialized: every test in this suite registers a stub for the same fixed OAuth token
// endpoint URL on CDYahooMockURLProtocol's shared, process-global registry (the token endpoint
// has one real URL — unlike Fantasy API resource endpoints, there's no per-test ID to bake into
// it for the usual "give each registration a unique URL" isolation). Serializing this suite
// stops its own tests from racing each other; it does not protect against interleaving with
// CDYahooFantasyAPIClientTests (Task 13), which is serialized for the same reason but as a
// different suite — an accepted residual risk, not a full fix.
@Suite("CDYahooOAuthClient", .serialized)
struct CDYahooOAuthClientTests {

    private func makeClient() -> CDYahooOAuthClient {
        let configuration = URLSessionConfiguration.ephemeral
        configuration.protocolClasses = [CDYahooMockURLProtocol.self]
        return CDYahooOAuthClient(clientId: "client-id", clientSecret: "client-secret",
                                   redirectUrl: "myapp://callback",
                                   urlSession: URLSession(configuration: configuration))
    }

    @Test("authorizationURL includes PKCE challenge, response_type=code, and state")
    func authorizationURLIncludesRequiredParameters() throws {
        let client = makeClient()
        let url = try client.authorizationURL(codeChallenge: "challenge-value", state: "state-value")
        let query = URLComponents(url: url, resolvingAgainstBaseURL: false)?.queryItems ?? []

        #expect(query.contains { $0.name == "code_challenge" && $0.value == "challenge-value" })
        #expect(query.contains { $0.name == "code_challenge_method" && $0.value == "S256" })
        #expect(query.contains { $0.name == "response_type" && $0.value == "code" })
        #expect(query.contains { $0.name == "state" && $0.value == "state-value" })
        #expect(query.contains { $0.name == "client_id" && $0.value == "client-id" })
    }

    @Test("isAuthorized is false before authorize(withCode:codeVerifier:) succeeds")
    func isAuthorizedFalseBeforeAuthorization() {
        let client = makeClient()
        client.unauthorize()
        #expect(client.isAuthorized() == false)
    }

    @Test("authorize(withCode:codeVerifier:) stores the token and flips isAuthorized to true")
    func authorizeStoresToken() async throws {
        let client = makeClient()
        client.unauthorize()

        CDYahooMockURLProtocol.register(
            stub: .init(statusCode: 200, data: Data("""
            {"access_token":"access-abc","refresh_token":"refresh-abc","expires_in":3600,"token_type":"bearer"}
            """.utf8)),
            for: URL(string: "https://api.login.yahoo.com/oauth2/get_token")!
        )

        try await client.authorize(withCode: "code-abc", codeVerifier: "verifier-abc")
        #expect(client.isAuthorized())
        #expect(try await client.validAccessToken() == "access-abc")
    }

    @Test("validAccessToken throws invalidCredentials when no refresh token is stored")
    func validAccessTokenThrowsWithoutRefreshToken() async {
        let client = makeClient()
        client.unauthorize()

        await #expect(throws: CDYahooKitError.self) {
            _ = try await client.validAccessToken()
        }
    }
}
