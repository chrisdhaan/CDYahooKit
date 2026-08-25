//
//  CDYahooFantasyAPIClient.swift
//  CDYahooKit
//

import Foundation

/// The primary client for the Yahoo Fantasy Sports API. Create one instance per application and
/// hold a strong reference to it. All methods are `@MainActor`.
@MainActor
public final class CDYahooFantasyAPIClient {

    private let session: CDYahooURLSession
    public let oAuthClient: CDYahooOAuthClient

    public init(clientId: String, clientSecret: String, redirectUrl: String,
                urlSession: URLSession = URLSession(configuration: .default),
                retryConfiguration: CDYahooRetryConfiguration = .disabled,
                eventMonitors: [any CDYahooEventMonitor] = [],
                requestAdapters: [any CDYahooRequestAdapter] = [],
                cacheConfiguration: CDYahooCacheConfiguration = .disabled) {
        self.oAuthClient = CDYahooOAuthClient(clientId: clientId, clientSecret: clientSecret, redirectUrl: redirectUrl,
                                               urlSession: urlSession)
        self.session = CDYahooURLSession(session: urlSession, retryConfiguration: retryConfiguration,
                                          eventMonitors: eventMonitors, requestAdapters: requestAdapters,
                                          cacheConfiguration: cacheConfiguration)
    }

    private func authorizedRequest(_ route: CDYahooRouter) async throws -> URLRequest {
        let token = try await oAuthClient.validAccessToken()
        return try route.asURLRequest(accessToken: token)
    }

    /// Fetches every fantasy game/season and league the authenticated user has a team in.
    /// - Parameter gameCode: The Yahoo game code, e.g. `"nfl"`, `"mlb"`, `"nba"`, `"nhl"`.
    public func fetchUserGames(gameCode: String = "nfl") async throws -> CDYahooUserGamesResponse {
        let request = try await authorizedRequest(.userGames(gameCode: gameCode))
        return try await session.perform(request)
    }

    /// Fetches a league's metadata and settings.
    public func fetchLeague(leagueKey: String) async throws -> CDYahooLeagueResponse {
        let request = try await authorizedRequest(.league(leagueKey: leagueKey))
        return try await session.perform(request)
    }

    /// Fetches a league's current standings, ranked by team.
    public func fetchLeagueStandings(leagueKey: String) async throws -> CDYahooLeagueStandingsResponse {
        let request = try await authorizedRequest(.standings(leagueKey: leagueKey))
        return try await session.perform(request)
    }

    /// Fetches a team's roster. Pass `week` to see the roster as it was set for a specific week;
    /// pass `nil` for the current roster.
    public func fetchTeamRoster(teamKey: String, week: Int?) async throws -> CDYahooTeamRosterResponse {
        let request = try await authorizedRequest(.roster(teamKey: teamKey, week: week))
        return try await session.perform(request)
    }
}
