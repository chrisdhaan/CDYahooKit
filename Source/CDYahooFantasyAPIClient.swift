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

    /// Fetches a league's player pool. Use ``CDYahooLeaguePlayersQuery`` to filter (by position,
    /// availability, or name), sort, page, and pull optional per-player sub-resources (season
    /// stats, ownership percentage, current owner). Pass `.init()` for Yahoo's first unfiltered
    /// page.
    public func fetchLeaguePlayers(leagueKey: String,
                                   query: CDYahooLeaguePlayersQuery = .init()) async throws -> CDYahooLeaguePlayersResponse {
        let request = try await authorizedRequest(.players(leagueKey: leagueKey, query: query))
        return try await session.perform(request)
    }

    /// Fetches a league's player pool one page at a time. Pass `start` (a zero-based offset) to
    /// page beyond Yahoo's default page size; pass `nil` for the first page.
    @available(*, deprecated,
               message: "Use fetchLeaguePlayers(leagueKey:query:) with CDYahooLeaguePlayersQuery(start:)")
    public func fetchLeaguePlayers(leagueKey: String, start: Int?) async throws -> CDYahooLeaguePlayersResponse {
        try await fetchLeaguePlayers(leagueKey: leagueKey, query: CDYahooLeaguePlayersQuery(start: start))
    }

    /// Fetches a league's scoreboard (every matchup) for a week. Pass `nil` for the current week.
    public func fetchLeagueScoreboard(leagueKey: String, week: Int?) async throws -> CDYahooLeagueScoreboardResponse {
        let request = try await authorizedRequest(.scoreboard(leagueKey: leagueKey, week: week))
        return try await session.perform(request)
    }

    /// Fetches a league's transaction history (adds, drops, trades, waiver claims).
    public func fetchLeagueTransactions(leagueKey: String) async throws -> CDYahooLeagueTransactionsResponse {
        let request = try await authorizedRequest(.transactions(leagueKey: leagueKey))
        return try await session.perform(request)
    }

    /// Fetches a league's settings: scoring type, roster positions, stat categories and their
    /// point modifiers, and the league's waiver, trade, and playoff rules.
    public func fetchLeagueSettings(leagueKey: String) async throws -> CDYahooLeagueSettingsResponse {
        let request = try await authorizedRequest(.settings(leagueKey: leagueKey))
        return try await session.perform(request)
    }

    /// Fetches every pick in a league's draft — round, pick number, the team that drafted, the
    /// player taken, and (auction drafts only) the winning bid.
    public func fetchLeagueDraftResults(leagueKey: String) async throws -> CDYahooLeagueDraftResultsResponse {
        let request = try await authorizedRequest(.leagueDraftResults(leagueKey: leagueKey))
        return try await session.perform(request)
    }

    /// Fetches one team's picks from the league's draft.
    public func fetchTeamDraftResults(teamKey: String) async throws -> CDYahooTeamDraftResultsResponse {
        let request = try await authorizedRequest(.teamDraftResults(teamKey: teamKey))
        return try await session.perform(request)
    }

    /// Fetches a team's head-to-head matchups, each with both sides' scores. Pass `weeks` to limit
    /// the result to specific weeks; pass `nil` (the default) for the team's full schedule.
    public func fetchTeamMatchups(teamKey: String, weeks: [Int]? = nil) async throws -> CDYahooTeamMatchupsResponse {
        let request = try await authorizedRequest(.teamMatchups(teamKey: teamKey, weeks: weeks))
        return try await session.perform(request)
    }

    /// Fetches a team's accumulated stats and fantasy points for a coverage window — the whole
    /// season (`.season`, the default) or a single week (`.week(_:)`).
    public func fetchTeamStats(teamKey: String,
                               coverage: CDYahooTeamStatsCoverage = .season) async throws -> CDYahooTeamStatsResponse {
        let request = try await authorizedRequest(.teamStats(teamKey: teamKey, coverage: coverage))
        return try await session.perform(request)
    }

    /// Fetches the stat categories a fantasy game scores — every stat, its display name, and the
    /// position types it applies to. Game-wide; an individual league scores a curated subset (see
    /// ``fetchLeagueSettings(leagueKey:)``).
    /// - Parameter gameKey: A Yahoo game key or game code, e.g. `"449"` or `"nfl"`.
    public func fetchGameStatCategories(gameKey: String) async throws -> CDYahooGameStatCategoriesResponse {
        let request = try await authorizedRequest(.gameStatCategories(gameKey: gameKey))
        return try await session.perform(request)
    }

    /// Fetches the player-position categories a fantasy game defines, e.g. offense, kickers,
    /// defense/special teams.
    /// - Parameter gameKey: A Yahoo game key or game code, e.g. `"449"` or `"nfl"`.
    public func fetchGamePositionTypes(gameKey: String) async throws -> CDYahooGamePositionTypesResponse {
        let request = try await authorizedRequest(.gamePositionTypes(gameKey: gameKey))
        return try await session.perform(request)
    }

    /// Fetches every roster position a fantasy game defines — the position code, its abbreviation
    /// and display name, and the position type it belongs to.
    /// - Parameter gameKey: A Yahoo game key or game code, e.g. `"449"` or `"nfl"`.
    public func fetchGameRosterPositions(gameKey: String) async throws -> CDYahooGameRosterPositionsResponse {
        let request = try await authorizedRequest(.gameRosterPositions(gameKey: gameKey))
        return try await session.perform(request)
    }

    /// Fetches a fantasy game's schedule of scoring periods — each week's number and the calendar
    /// dates it spans.
    /// - Parameter gameKey: A Yahoo game key or game code, e.g. `"449"` or `"nfl"`.
    public func fetchGameWeeks(gameKey: String) async throws -> CDYahooGameWeeksResponse {
        let request = try await authorizedRequest(.gameWeeks(gameKey: gameKey))
        return try await session.perform(request)
    }
}
