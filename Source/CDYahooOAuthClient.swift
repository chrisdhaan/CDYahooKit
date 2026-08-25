//
//  CDYahooOAuthClient.swift
//  CDYahooKit
//

import Foundation

/// Manages the Sign In With Yahoo OAuth 2.0 / PKCE authorization code flow: builds the
/// authorization URL, exchanges a code for a token pair, refreshes silently when the access
/// token has expired, and stores everything in the Keychain via ``CDYahooKeychain``.
public final class CDYahooOAuthClient: Sendable {

    private let session: URLSession
    public let clientId: String
    public let clientSecret: String
    public let redirectUrl: String

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
    /// fresh random value checked against the callback to guard against CSRF.
    public func authorizationURL(codeChallenge: String, state: String) throws -> URL {
        var components = URLComponents(string: CDYahooConstants.oauthAuthorizeURL)
        components?.queryItems = [
            URLQueryItem(name: "client_id", value: clientId),
            URLQueryItem(name: "redirect_uri", value: redirectUrl),
            URLQueryItem(name: "response_type", value: "code"),
            URLQueryItem(name: "code_challenge", value: codeChallenge),
            URLQueryItem(name: "code_challenge_method", value: "S256"),
            URLQueryItem(name: "state", value: state)
        ]
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

    public func isAuthorized() -> Bool {
        CDYahooKeychain.string(forKey: CDYahooDefaults.accessToken) != nil
    }

    /// Returns a currently-valid access token, silently refreshing it first if it has expired.
    /// - Throws: ``CDYahooKitError/invalidCredentials(_:)`` if no refresh token is stored — the
    ///   caller must re-run the `ASWebAuthenticationSession` authorization flow.
    public func validAccessToken() async throws -> String {
        if let expiryString = CDYahooKeychain.string(forKey: CDYahooDefaults.tokenExpiry),
           let expiry = Double(expiryString),
           Date().timeIntervalSince1970 < expiry,
           let token = CDYahooKeychain.string(forKey: CDYahooDefaults.accessToken) {
            return token
        }
        guard let refreshToken = CDYahooKeychain.string(forKey: CDYahooDefaults.refreshToken) else {
            throw CDYahooKitError.invalidCredentials("No refresh token stored; re-authorize with Sign In With Yahoo.")
        }
        let request = try CDYahooOAuthRouter.refresh(refreshToken: refreshToken, redirectUrl: redirectUrl)
            .asURLRequest(clientId: clientId, clientSecret: clientSecret)
        let credential = try await performTokenRequest(request)
        store(credential)
        return credential.accessToken
    }

    /// Clears all stored tokens, e.g. on user sign-out.
    public func unauthorize() {
        CDYahooKeychain.delete(forKey: CDYahooDefaults.accessToken)
        CDYahooKeychain.delete(forKey: CDYahooDefaults.refreshToken)
        CDYahooKeychain.delete(forKey: CDYahooDefaults.tokenExpiry)
    }

    private func performTokenRequest(_ request: URLRequest) async throws -> CDYahooOAuthCredential {
        let (data, response) = try await session.data(for: request)
        guard let httpResponse = response as? HTTPURLResponse, (200..<300).contains(httpResponse.statusCode) else {
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
