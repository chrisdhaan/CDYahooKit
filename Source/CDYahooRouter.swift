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

    var path: String {
        switch self {
        case let .userGames(gameCode):
            "users;use_login=1/games;game_codes=\(gameCode)/leagues"
        case let .league(leagueKey):
            "league/\(leagueKey)"
        case let .standings(leagueKey):
            "league/\(leagueKey)/standings"
        case let .roster(teamKey, week):
            if let week {
                "team/\(teamKey)/roster;week=\(week)"
            } else {
                "team/\(teamKey)/roster"
            }
        case let .players(leagueKey, start):
            if let start {
                "league/\(leagueKey)/players;start=\(start)"
            } else {
                "league/\(leagueKey)/players"
            }
        case let .scoreboard(leagueKey, week):
            if let week {
                "league/\(leagueKey)/scoreboard;week=\(week)"
            } else {
                "league/\(leagueKey)/scoreboard"
            }
        }
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
