//
//  ViewController.swift
//  iOS Example
//

import CDYahooKit
import UIKit

/// Demonstrates the full Sign In With Yahoo authorization code + PKCE flow: a single button
/// kicks off `CDYahooAuthSession`, exchanges the resulting code for tokens via
/// `CDYahooOAuthClient`, then fetches and prints the signed-in user's fantasy leagues.
final class ViewController: UIViewController {

    private let client: CDYahooFantasyAPIClient = {
        let clientId = Bundle.main.object(forInfoDictionaryKey: "YAHOO_CLIENT_ID") as? String ?? ""
        let clientSecret = Bundle.main.object(forInfoDictionaryKey: "YAHOO_CLIENT_SECRET") as? String ?? ""
        let redirectUrl = Bundle.main.object(forInfoDictionaryKey: "YAHOO_REDIRECT_URL") as? String ?? ""
        return CDYahooFantasyAPIClient(clientId: clientId, clientSecret: clientSecret, redirectUrl: redirectUrl)
    }()

    /// Retained for the lifetime of the in-flight authorization — `CDYahooAuthSession` itself
    /// already retains its underlying `ASWebAuthenticationSession`, but we hold the wrapper too
    /// so it isn't deallocated out from under that session while the user is in Safari.
    private var authSession: CDYahooAuthSession?

    override func viewDidLoad() {
        super.viewDidLoad()

        view.backgroundColor = .systemBackground
        title = "CDYahooKit Example"

        let signInButton = UIButton(type: .system)
        signInButton.setTitle("Sign In With Yahoo", for: .normal)
        signInButton.titleLabel?.font = .preferredFont(forTextStyle: .headline)
        signInButton.translatesAutoresizingMaskIntoConstraints = false
        signInButton.addTarget(self, action: #selector(signInButtonTapped), for: .touchUpInside)
        view.addSubview(signInButton)

        NSLayoutConstraint.activate([
            signInButton.centerXAnchor.constraint(equalTo: view.safeAreaLayoutGuide.centerXAnchor),
            signInButton.centerYAnchor.constraint(equalTo: view.safeAreaLayoutGuide.centerYAnchor)
        ])
    }

    @objc
    private func signInButtonTapped() {
        Task { await signIn() }
    }

    private func signIn() async {
        do {
            let codeVerifier = CDYahooPKCE.makeCodeVerifier()
            let codeChallenge = CDYahooPKCE.codeChallenge(for: codeVerifier)
            let state = UUID().uuidString

            let authorizationURL = try client.oAuthClient.authorizationURL(codeChallenge: codeChallenge, state: state)

            let session = CDYahooAuthSession(presentationAnchor: self.view.window!)
            authSession = session
            let callbackURL = try await session.authorize(
                authorizationURL: authorizationURL,
                callbackScheme: "cdyahookitexample"
            )
            authSession = nil

            let code = try CDYahooAuthSession.extractCode(from: callbackURL, expectedState: state)
            try await client.oAuthClient.authorize(withCode: code, codeVerifier: codeVerifier)

            let leagueListViewController = LeagueListViewController()
            leagueListViewController.client = client
            navigationController?.pushViewController(leagueListViewController, animated: true)
        } catch {
            authSession = nil
            print("Sign In With Yahoo failed: \(error)")
        }
    }
}
