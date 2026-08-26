//
//  CDYahooAuthSession.swift
//  CDYahooKit
//

import AuthenticationServices
import Foundation

/// An `async`/`await` wrapper around `ASWebAuthenticationSession` for the browser-redirect step
/// of Sign In With Yahoo's OAuth 2.0 authorization code flow — modeled directly on CDOAuth1Kit's
/// `CDOAuth1AuthSession`. The only functional difference is what comes back in the callback URL:
/// an OAuth 1.0a `oauth_verifier` there, versus an OAuth 2.0 `code` (+ `state`) here.
///
/// ```swift
/// let verifier = CDYahooPKCE.makeCodeVerifier()
/// let challenge = CDYahooPKCE.codeChallenge(for: verifier)
/// let state = UUID().uuidString
/// let authURL = try await oAuthClient.authorizationURL(codeChallenge: challenge, state: state)
/// let callback = try await CDYahooAuthSession(presentationAnchor: view.window!)
///     .authorize(authorizationURL: authURL, callbackScheme: "myapp")
/// let code = try CDYahooAuthSession.extractCode(from: callback, expectedState: state)
/// try await oAuthClient.authorize(withCode: code, codeVerifier: verifier)
/// ```
@available(iOS 12.0, macOS 10.15, visionOS 1.0, *)
public final class CDYahooAuthSession: NSObject {

    private let presentationAnchorProvider: () -> ASPresentationAnchor

    /// Retains the in-flight `ASWebAuthenticationSession` — see `CDOAuth1AuthSession`'s
    /// identical property for why this is required rather than incidental.
    private var activeSession: ASWebAuthenticationSession?

    public init(presentationAnchor: @autoclosure @escaping () -> ASPresentationAnchor) {
        self.presentationAnchorProvider = presentationAnchor
        super.init()
    }

    public func authorize(authorizationURL: URL, callbackScheme: String) async throws -> URL {
        try await withCheckedThrowingContinuation { continuation in
            let session = ASWebAuthenticationSession(
                url: authorizationURL,
                callbackURLScheme: callbackScheme
            ) { [weak self] callbackURL, error in
                self?.activeSession = nil
                do {
                    try continuation.resume(returning: Self.mapCallback(url: callbackURL, error: error))
                } catch {
                    continuation.resume(throwing: error)
                }
            }
            session.presentationContextProvider = self
            activeSession = session
            session.start()
        }
    }

    static func mapCallback(url callbackURL: URL?, error: (any Error)?) throws -> URL {
        if let error = error as? ASWebAuthenticationSessionError, error.code == .canceledLogin {
            throw CDYahooKitError.authorizationCancelled
        }
        if let error {
            throw error
        }
        guard let callbackURL else {
            throw CDYahooKitError.responseDecodingFailed(underlying: URLError(.badServerResponse))
        }
        return callbackURL
    }

    /// Extracts the OAuth 2.0 authorization `code` from a callback URL, verifying its `state`
    /// query item matches `expectedState` first, as a CSRF guard.
    public static func extractCode(from callbackURL: URL, expectedState: String) throws -> String {
        let items = URLComponents(url: callbackURL, resolvingAgainstBaseURL: false)?.queryItems ?? []
        guard let state = items.first(where: { $0.name == "state" })?.value, state == expectedState else {
            throw CDYahooKitError.invalidCredentials("OAuth state mismatch; possible CSRF, discard this callback.")
        }
        guard let code = items.first(where: { $0.name == "code" })?.value else {
            throw CDYahooKitError.invalidCredentials("Authorization callback did not include a code.")
        }
        return code
    }
}

@available(iOS 12.0, macOS 10.15, visionOS 1.0, *)
extension CDYahooAuthSession: ASWebAuthenticationPresentationContextProviding {
    public func presentationAnchor(for session: ASWebAuthenticationSession) -> ASPresentationAnchor {
        presentationAnchorProvider()
    }
}
