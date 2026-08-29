//
//  CDYahooKitManager.swift
//  iOS Example
//

import AuthenticationServices
import CDYahooKit
import Foundation

/// Owns the single `CDYahooFantasyAPIClient` for the Example app, drives the Sign In With Yahoo
/// authorization-code + PKCE flow, and remembers a league/team discovered from the signed-in
/// user so the league- and team-scoped endpoint rows have something to request.
@MainActor
final class CDYahooKitManager {

    static let shared = CDYahooKitManager()

    private static let callbackScheme = "cdyahookitexample"

    private(set) var client: CDYahooFantasyAPIClient!

    private let responseRecorder = XMLResponseRecorder()

    /// `true` once an access token is available, whether from an interactive sign-in this
    /// launch or a token left in the keychain by a previous run.
    private(set) var isSignedIn = false

    /// Discovered from the signed-in user's first game/league; parameterizes the league-scoped
    /// endpoint rows.
    private(set) var leagueKey: String?

    /// Discovered from the first team in ``leagueKey``'s standings; parameterizes the team roster row.
    private(set) var teamKey: String?

    /// The game-key prefix of ``leagueKey`` (`{game_key}.l.{league_id}`); parameterizes the
    /// game-metadata endpoint rows.
    var gameKey: String? {
        leagueKey.flatMap { $0.split(separator: ".").first.map(String.init) }
    }

    /// Retained for the lifetime of the in-flight authorization so the wrapper isn't
    /// deallocated out from under `ASWebAuthenticationSession` while the user is in Safari.
    private var authSession: CDYahooAuthSession?

    private init() {}

    /// Pretty-printed XML of the most recent Fantasy Sports API response, captured by the
    /// event monitor handed to the client.
    var lastResponseXML: String? {
        responseRecorder.lastResponseBody.map(XMLPrettyPrinter.string(from:))
    }

    /// Builds the API client. `clientId` / `clientSecret` / `redirectUrl` come from
    /// `Secrets.xcconfig` via `Info.plist` — copy `Secrets.xcconfig.example` to
    /// `Secrets.xcconfig` and fill in your own Yahoo app credentials before running.
    func configure() {
        let clientId = Bundle.main.object(forInfoDictionaryKey: "YAHOO_CLIENT_ID") as? String ?? ""
        let clientSecret = Bundle.main.object(forInfoDictionaryKey: "YAHOO_CLIENT_SECRET") as? String ?? ""
        let redirectUrl = Bundle.main.object(forInfoDictionaryKey: "YAHOO_REDIRECT_URL") as? String ?? ""

        client = CDYahooFantasyAPIClient(
            clientId: clientId,
            clientSecret: clientSecret,
            redirectUrl: redirectUrl,
            eventMonitors: [responseRecorder]
        )
    }

    /// Called once when the endpoint list first appears: picks up a keychain token from a
    /// previous run and, if present, discovers a league/team up front.
    func start() async {
        isSignedIn = await client.oAuthClient.isAuthorized()
        if isSignedIn {
            try? await discoverLeagueAndTeam()
        }
    }

    /// Runs the full authorization-code + PKCE handshake, then discovers a league/team.
    ///
    /// - Parameter presentationAnchor: The window to present the browser sheet from.
    func signIn(presentationAnchor: ASPresentationAnchor) async throws {
        let codeVerifier = CDYahooPKCE.makeCodeVerifier()
        let codeChallenge = CDYahooPKCE.codeChallenge(for: codeVerifier)
        let state = UUID().uuidString

        let authorizationURL = try await client.oAuthClient.authorizationURL(
            codeChallenge: codeChallenge,
            state: state
        )

        let session = CDYahooAuthSession(presentationAnchor: presentationAnchor)
        authSession = session
        defer { authSession = nil }

        let callbackURL = try await session.authorize(
            authorizationURL: authorizationURL,
            callbackScheme: Self.callbackScheme
        )
        let code = try CDYahooAuthSession.extractCode(from: callbackURL, expectedState: state)
        try await client.oAuthClient.authorize(withCode: code, codeVerifier: codeVerifier)

        isSignedIn = true
        try await discoverLeagueAndTeam()
    }

    /// Discards the stored tokens and the discovered league/team.
    func signOut() async {
        await client.oAuthClient.unauthorize()
        isSignedIn = false
        leagueKey = nil
        teamKey = nil
    }

    /// - Returns: The discovered league key.
    /// - Throws: ``ExampleError/noLeagueFound`` if the signed-in account has no fantasy league.
    func requireLeagueKey() throws -> String {
        guard let leagueKey else { throw ExampleError.noLeagueFound }
        return leagueKey
    }

    /// - Returns: The discovered team key.
    /// - Throws: ``ExampleError/noTeamFound`` if the discovered league had no teams.
    func requireTeamKey() throws -> String {
        guard let teamKey else { throw ExampleError.noTeamFound }
        return teamKey
    }

    /// - Returns: The game key derived from the discovered league.
    /// - Throws: ``ExampleError/noLeagueFound`` if the signed-in account has no fantasy league.
    func requireGameKey() throws -> String {
        guard let gameKey else { throw ExampleError.noLeagueFound }
        return gameKey
    }

    private func discoverLeagueAndTeam() async throws {
        let userGames = try await client.fetchUserGames()
        leagueKey = userGames.games.first(where: { !$0.leagues.isEmpty })?.leagues.first?.leagueKey

        guard let leagueKey else { return }
        let standings = try await client.fetchLeagueStandings(leagueKey: leagueKey)
        teamKey = standings.teams.first?.teamKey
    }
}

/// Errors surfaced by the Example itself when the signed-in account can't satisfy a demo request.
enum ExampleError: LocalizedError {

    case noLeagueFound
    case noTeamFound

    var errorDescription: String? {
        switch self {
        case .noLeagueFound:
            "No fantasy league was found for this account. This demo needs a Yahoo account that plays fantasy football."
        case .noTeamFound:
            "No team was found in the discovered league."
        }
    }
}
