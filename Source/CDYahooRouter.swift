//
//  CDYahooRouter.swift
//  CDYahooKit
//

import Foundation

/// Builds requests against the Yahoo Fantasy Sports API (`fantasysports.yahooapis.com/fantasy/v2/`).
/// Every case is a read-only `GET` for v1.
enum CDYahooRouter {
    case userGames(gameCode: String)
    case league(leagueKey: String)
    case standings(leagueKey: String)
    case roster(teamKey: String, week: Int?)
    case players(leagueKey: String, start: Int?)
    case scoreboard(leagueKey: String, week: Int?)
    case transactions(leagueKey: String)
    case settings(leagueKey: String)
    case leagueDraftResults(leagueKey: String)
    case teamDraftResults(teamKey: String)
    case teamMatchups(teamKey: String, weeks: [Int]?)
    case teamStats(teamKey: String, coverage: CDYahooTeamStatsCoverage)
    case gameStatCategories(gameKey: String)
    case gamePositionTypes(gameKey: String)
    case gameRosterPositions(gameKey: String)
    case gameWeeks(gameKey: String)

    var path: String {
        switch self {
        case let .userGames(gameCode):
            "users;use_login=1/games;game_codes=\(Self.percentEncodedPathSegment(gameCode))/leagues"
        case let .league(leagueKey):
            "league/\(Self.percentEncodedPathSegment(leagueKey))"
        case let .standings(leagueKey):
            "league/\(Self.percentEncodedPathSegment(leagueKey))/standings"
        case let .roster(teamKey, week):
            if let week {
                "team/\(Self.percentEncodedPathSegment(teamKey))/roster;week=\(week)"
            } else {
                "team/\(Self.percentEncodedPathSegment(teamKey))/roster"
            }
        case let .players(leagueKey, start):
            if let start {
                "league/\(Self.percentEncodedPathSegment(leagueKey))/players;start=\(start)"
            } else {
                "league/\(Self.percentEncodedPathSegment(leagueKey))/players"
            }
        case let .scoreboard(leagueKey, week):
            if let week {
                "league/\(Self.percentEncodedPathSegment(leagueKey))/scoreboard;week=\(week)"
            } else {
                "league/\(Self.percentEncodedPathSegment(leagueKey))/scoreboard"
            }
        case let .transactions(leagueKey):
            "league/\(Self.percentEncodedPathSegment(leagueKey))/transactions"
        case let .settings(leagueKey):
            "league/\(Self.percentEncodedPathSegment(leagueKey))/settings"
        case let .leagueDraftResults(leagueKey):
            "league/\(Self.percentEncodedPathSegment(leagueKey))/draftresults"
        case let .teamDraftResults(teamKey):
            "team/\(Self.percentEncodedPathSegment(teamKey))/draftresults"
        case let .teamMatchups(teamKey, weeks):
            if let weeks, !weeks.isEmpty {
                "team/\(Self.percentEncodedPathSegment(teamKey))/matchups;weeks=\(weeks.map(String.init).joined(separator: ","))"
            } else {
                "team/\(Self.percentEncodedPathSegment(teamKey))/matchups"
            }
        case let .teamStats(teamKey, coverage):
            "team/\(Self.percentEncodedPathSegment(teamKey))/stats\(coverage.pathModifier)"
        case let .gameStatCategories(gameKey):
            "game/\(Self.percentEncodedPathSegment(gameKey))/stat_categories"
        case let .gamePositionTypes(gameKey):
            "game/\(Self.percentEncodedPathSegment(gameKey))/position_types"
        case let .gameRosterPositions(gameKey):
            "game/\(Self.percentEncodedPathSegment(gameKey))/roster_positions"
        case let .gameWeeks(gameKey):
            "game/\(Self.percentEncodedPathSegment(gameKey))/game_weeks"
        }
    }

    /// Percent-encodes a value that gets interpolated directly into a URL path segment (a league
    /// key, team key, or game code) so a value containing `?`/`#`/`/` can't silently reshape the
    /// URL — it either encodes cleanly or the request fails, rather than hitting the wrong route.
    private static func percentEncodedPathSegment(_ value: String) -> String {
        var allowed = CharacterSet.alphanumerics
        allowed.insert(charactersIn: "-._~")
        return value.addingPercentEncoding(withAllowedCharacters: allowed) ?? value
    }

    func asURLRequest(accessToken: String) throws -> URLRequest {
        guard let url = URL(string: CDYahooConstants.fantasyBaseURL + path) else {
            throw CDYahooKitError.invalidRequest(underlying: URLError(.badURL))
        }
        var request = URLRequest(url: url)
        request.httpMethod = "GET"
        request.setValue("Bearer \(accessToken)", forHTTPHeaderField: "Authorization")
        request.setValue("application/xml", forHTTPHeaderField: "Accept")
        return request
    }
}
