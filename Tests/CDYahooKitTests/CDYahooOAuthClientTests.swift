//
//  CDYahooOAuthClientTests.swift
//  CDYahooKitTests
//

import CDYahooKitTesting
import Foundation
import Testing
@testable import CDYahooKit

// .serialized: every test in this suite registers a stub for the same fixed OAuth token
// endpoint URL on CDYahooMockURLProtocol's shared, process-global registry (the token endpoint
// has one real URL — unlike Fantasy API resource endpoints, there's no per-test ID to bake into
// it for the usual "give each registration a unique URL" isolation). Serializing this suite
// stops its own tests from racing each other. It also closes the cross-suite race with
// CDYahooFantasyAPIClientTests, which shares the same process-global Keychain: that suite is
// nested inside this one via `extension CDYahooOAuthClientTests` (see
// CDYahooFantasyAPIClientTests.swift), and Swift Testing's `.serialized` trait cascades to
// nested sub-suites — so both suites run under this single `.serialized` umbrella rather than as
// two independently-serialized top-level suites that could still run concurrently with each
// other. This is a full fix for that race, not merely a mitigation.
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
    func authorizationURLIncludesRequiredParameters() async throws {
        let client = makeClient()
        let url = try await client.authorizationURL(codeChallenge: "challenge-value", state: "state-value")
        let query = URLComponents(url: url, resolvingAgainstBaseURL: false)?.queryItems ?? []

        #expect(query.contains { $0.name == "code_challenge" && $0.value == "challenge-value" })
        #expect(query.contains { $0.name == "code_challenge_method" && $0.value == "S256" })
        #expect(query.contains { $0.name == "response_type" && $0.value == "code" })
        #expect(query.contains { $0.name == "state" && $0.value == "state-value" })
        #expect(query.contains { $0.name == "client_id" && $0.value == "client-id" })
    }

    @Test("isAuthorized is false before authorize(withCode:codeVerifier:) succeeds")
    func isAuthorizedFalseBeforeAuthorization() async {
        let client = makeClient()
        await client.unauthorize()
        #expect(await client.isAuthorized() == false)
    }

    @Test("authorize(withCode:codeVerifier:) stores the token and flips isAuthorized to true")
    func authorizeStoresToken() async throws {
        let client = makeClient()
        await client.unauthorize()

        try CDYahooMockURLProtocol.register(
            stub: .init(statusCode: 200, data: Data("""
            {"access_token":"access-abc","refresh_token":"refresh-abc","expires_in":3600,"token_type":"bearer"}
            """.utf8)),
            for: #require(URL(string: "https://api.login.yahoo.com/oauth2/get_token"))
        )

        try await client.authorize(withCode: "code-abc", codeVerifier: "verifier-abc")
        #expect(await client.isAuthorized())
        #expect(try await client.validAccessToken() == "access-abc")

        // Leave clean state for the next test in this .serialized suite.
        await client.unauthorize()
    }

    @Test("validAccessToken throws invalidCredentials when no refresh token is stored")
    func validAccessTokenThrowsWithoutRefreshToken() async {
        let client = makeClient()
        await client.unauthorize()

        await #expect(throws: CDYahooKitError.self) {
            _ = try await client.validAccessToken()
        }
    }

    @Test("invalid_grant on refresh surfaces Yahoo's error_description and clears stored credentials")
    func invalidGrantClearsStoredCredentials() async throws {
        let client = makeClient()
        await client.unauthorize()

        try CDYahooMockURLProtocol.register(
            stub: .init(statusCode: 200, data: Data("""
            {"access_token":"access-abc","refresh_token":"refresh-abc","expires_in":3600,"token_type":"bearer"}
            """.utf8)),
            for: #require(URL(string: "https://api.login.yahoo.com/oauth2/get_token"))
        )
        try await client.authorize(withCode: "code-abc", codeVerifier: "verifier-abc")

        // Force the stored token to look expired so the next validAccessToken() call must
        // refresh, then make that refresh fail with Yahoo's invalid_grant error body.
        CDYahooKeychain.set(String(Date().timeIntervalSince1970 - 100), forKey: CDYahooDefaults.tokenExpiry)
        try CDYahooMockURLProtocol.register(
            stub: .init(statusCode: 400, data: Data("""
            {"error":"invalid_grant","error_description":"Refresh token expired"}
            """.utf8)),
            for: #require(URL(string: "https://api.login.yahoo.com/oauth2/get_token"))
        )

        let thrown = try await #require(throws: CDYahooKitError.self) {
            _ = try await client.validAccessToken()
        }
        #expect(thrown.errorDescription == "Refresh token expired")
        #expect(await client.isAuthorized() == false)
    }

    @Test("concurrent validAccessToken calls near expiry coalesce into a single refresh request")
    func concurrentValidAccessTokenCoalescesRefresh() async throws {
        let client = makeClient()
        await client.unauthorize()

        try CDYahooMockURLProtocol.register(
            stub: .init(statusCode: 200, data: Data("""
            {"access_token":"access-initial","refresh_token":"refresh-initial","expires_in":3600,"token_type":"bearer"}
            """.utf8)),
            for: #require(URL(string: "https://api.login.yahoo.com/oauth2/get_token"))
        )
        try await client.authorize(withCode: "code-abc", codeVerifier: "verifier-abc")

        // Force the stored access token to look expired so the next validAccessToken() call(s)
        // must refresh. re-registering the stub also resets requestCount to 0, so if two
        // concurrent callers each fired their own refresh request, the mock's requestCount for
        // this URL below would be 2, not 1.
        CDYahooKeychain.set(String(Date().timeIntervalSince1970 - 100), forKey: CDYahooDefaults.tokenExpiry)
        try CDYahooMockURLProtocol.register(
            stub: .init(statusCode: 200, data: Data("""
            {"access_token":"access-refreshed","refresh_token":"refresh-refreshed","expires_in":3600,"token_type":"bearer"}
            """.utf8)),
            for: #require(URL(string: "https://api.login.yahoo.com/oauth2/get_token"))
        )

        async let first = client.validAccessToken()
        async let second = client.validAccessToken()
        let (tokenA, tokenB) = try await (first, second)

        #expect(tokenA == "access-refreshed")
        #expect(tokenB == "access-refreshed")
        #expect(try CDYahooMockURLProtocol.requestCount(for: #require(URL(string: "https://api.login.yahoo.com/oauth2/get_token"))) == 1)

        // Leave clean state for the next test in this .serialized suite.
        await client.unauthorize()
    }
}
