//
//  CDYahooOAuthClient.swift
//  CDYahooKit
//

import Foundation

/// Manages the Sign In With Yahoo OAuth 2.0 / PKCE authorization code flow: builds the
/// authorization URL, exchanges a code for a token pair, refreshes silently when the access
/// token has expired, and stores everything in the Keychain via ``CDYahooKeychain``.
///
/// An `actor` (not a plain `Sendable` class) so concurrent calls to ``validAccessToken()`` near
/// token expiry can't each read the same expired token and each fire their own refresh: Yahoo
/// rotates refresh tokens on every use, so two concurrent refreshes would race to consume the
/// same refresh token, and the loser would fail with `invalid_grant`. Actor isolation plus the
/// cached in-flight `refreshTask` in ``validAccessToken()`` makes every concurrent caller await
/// the *same* single refresh instead.
public actor CDYahooOAuthClient {

    private let session: URLSession
    public let clientId: String
    public let clientSecret: String
    public let redirectUrl: String
    private var refreshTask: Task<String, any Error>?

    public init(clientId: String, clientSecret: String, redirectUrl: String,
                urlSession: URLSession = URLSession(configuration: .default)) {
        precondition(!clientId.isEmpty && !clientSecret.isEmpty && !redirectUrl.isEmpty,
                     "A clientId, clientSecret, and redirectUrl are required to use Sign In With Yahoo.")
        self.clientId = clientId
        self.clientSecret = clientSecret
        self.redirectUrl = redirectUrl
        self.session = urlSession
    }

    /// The URL to present in an `ASWebAuthenticationSession` to begin the authorization code
    /// flow. `codeChallenge` comes from `CDYahooPKCE.codeChallenge(for:)`; `state` should be a
    /// fresh random value checked against the callback to guard against CSRF. `scope` is omitted
    /// from the URL when `nil` (the default), preserving Yahoo's default scope grant for the app;
    /// pass e.g. `"openid fspt-r"` to additionally request Sign In With Yahoo identity/userinfo
    /// alongside fantasy sports access.
    public func authorizationURL(codeChallenge: String, state: String, scope: String? = nil) throws -> URL {
        var components = URLComponents(string: CDYahooConstants.oauthAuthorizeURL)
        var queryItems = [
            URLQueryItem(name: "client_id", value: clientId),
            URLQueryItem(name: "redirect_uri", value: redirectUrl),
            URLQueryItem(name: "response_type", value: "code"),
            URLQueryItem(name: "code_challenge", value: codeChallenge),
            URLQueryItem(name: "code_challenge_method", value: "S256"),
            URLQueryItem(name: "state", value: state)
        ]
        if let scope {
            queryItems.append(URLQueryItem(name: "scope", value: scope))
        }
        components?.queryItems = queryItems
        guard let url = components?.url else {
            throw CDYahooKitError.invalidRequest(underlying: URLError(.badURL))
        }
        return url
    }

    /// Exchanges an authorization `code` (from the callback URL) and the PKCE `codeVerifier`
    /// that produced its challenge for an access/refresh token pair, storing both in the
    /// Keychain.
    public func authorize(withCode code: String, codeVerifier: String) async throws {
        let request = try CDYahooOAuthRouter.authorize(code: code, redirectUrl: redirectUrl, codeVerifier: codeVerifier)
            .asURLRequest(clientId: clientId, clientSecret: clientSecret)
        let credential = try await performTokenRequest(request)
        store(credential)
    }

    /// Whether there's a currently-usable session: either the access token hasn't expired yet, or
    /// a refresh token is stored that can silently mint a new one. Synchronous and non-refreshing
    /// by design — it's a cheap "should I show a Sign In button?" check, not a network call.
    public func isAuthorized() -> Bool {
        if isAccessTokenValid() {
            return true
        }
        return CDYahooKeychain.string(forKey: CDYahooDefaults.refreshToken) != nil
    }

    private func isAccessTokenValid() -> Bool {
        guard let expiryString = CDYahooKeychain.string(forKey: CDYahooDefaults.tokenExpiry),
              let expiry = Double(expiryString),
              Date().timeIntervalSince1970 < expiry,
              CDYahooKeychain.string(forKey: CDYahooDefaults.accessToken) != nil else {
            return false
        }
        return true
    }

    /// Returns a currently-valid access token, silently refreshing it first if it has expired.
    /// Concurrent callers that arrive while a refresh is already in flight await that same
    /// refresh rather than each starting their own — see the type-level doc comment for why.
    /// - Throws: ``CDYahooKitError/invalidCredentials(_:)`` if no refresh token is stored — the
    ///   caller must re-run the `ASWebAuthenticationSession` authorization flow.
    public func validAccessToken() async throws -> String {
        if isAccessTokenValid(), let token = CDYahooKeychain.string(forKey: CDYahooDefaults.accessToken) {
            return token
        }
        if let refreshTask {
            return try await refreshTask.value
        }
        let task = Task<String, any Error> {
            guard let refreshToken = CDYahooKeychain.string(forKey: CDYahooDefaults.refreshToken) else {
                throw CDYahooKitError.invalidCredentials("No refresh token stored; re-authorize with Sign In With Yahoo.")
            }
            let request = try CDYahooOAuthRouter.refresh(refreshToken: refreshToken, redirectUrl: redirectUrl)
                .asURLRequest(clientId: clientId, clientSecret: clientSecret)
            let credential = try await performTokenRequest(request)
            store(credential)
            return credential.accessToken
        }
        refreshTask = task
        defer { refreshTask = nil }
        return try await task.value
    }

    /// Clears all stored tokens, e.g. on user sign-out.
    public func unauthorize() {
        CDYahooKeychain.delete(forKey: CDYahooDefaults.accessToken)
        CDYahooKeychain.delete(forKey: CDYahooDefaults.refreshToken)
        CDYahooKeychain.delete(forKey: CDYahooDefaults.tokenExpiry)
    }

    private func performTokenRequest(_ request: URLRequest) async throws -> CDYahooOAuthCredential {
        let (data, response) = try await session.data(for: request)
        guard let httpResponse = response as? HTTPURLResponse, (200 ..< 300).contains(httpResponse.statusCode) else {
            if let tokenError = try? JSONDecoder().decode(CDYahooOAuthTokenErrorResponse.self, from: data) {
                if tokenError.error == "invalid_grant" {
                    // The refresh token itself is dead (revoked/rotated away) — clear stored
                    // credentials so isAuthorized() stops lying and the caller knows to re-run
                    // Sign In With Yahoo, instead of retrying a dead refresh token forever.
                    unauthorize()
                }
                throw CDYahooKitError.invalidCredentials(tokenError.errorDescription ?? tokenError.error)
            }
            throw CDYahooKitError.invalidCredentials("Yahoo's OAuth token endpoint returned a non-2xx response.")
        }
        do {
            return try JSONDecoder().decode(CDYahooOAuthCredential.self, from: data)
        } catch {
            throw CDYahooKitError.responseDecodingFailed(underlying: error)
        }
    }

    private func store(_ credential: CDYahooOAuthCredential) {
        CDYahooKeychain.set(credential.accessToken, forKey: CDYahooDefaults.accessToken)
        if let refreshToken = credential.refreshToken {
            CDYahooKeychain.set(refreshToken, forKey: CDYahooDefaults.refreshToken)
        }
        // Subtract 60s so a token that's about to expire mid-request is refreshed early rather
        // than used and rejected.
        let expiry = Date().timeIntervalSince1970 + Double(credential.expiresIn) - 60
        CDYahooKeychain.set(String(expiry), forKey: CDYahooDefaults.tokenExpiry)
    }
}

/// The JSON error body Yahoo's OAuth 2.0 token endpoint returns on a non-2xx response, e.g.
/// `{"error":"invalid_grant","error_description":"..."}`.
private struct CDYahooOAuthTokenErrorResponse: Decodable {
    let error: String
    let errorDescription: String?

    enum CodingKeys: String, CodingKey {
        case error
        case errorDescription = "error_description"
    }
}
