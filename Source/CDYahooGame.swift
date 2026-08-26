//
//  CDYahooGame.swift
//  CDYahooKit
//

/// A team's league within one fantasy game/season, as summarized inside `CDYahooGame`.
public struct CDYahooLeagueSummary: CDYahooXMLDecodable, Sendable, Equatable {
    public let leagueKey: String
    public let leagueId: String
    public let name: String
    public let numTeams: Int?

    public init(leagueKey: String, leagueId: String, name: String, numTeams: Int?) {
        self.leagueKey = leagueKey
        self.leagueId = leagueId
        self.name = name
        self.numTeams = numTeams
    }

    init(node: CDYahooXMLNode) throws {
        guard let leagueKey = node.text("league_key"), let leagueId = node.text("league_id"), let name = node.text("name") else {
            throw CDYahooXMLDecodingError.missingField("league")
        }
        self.leagueKey = leagueKey
        self.leagueId = leagueId
        self.name = name
        self.numTeams = node.int("num_teams")
    }
}

/// A fantasy game (a sport + season, e.g. "Football" / "nfl" / 2025) the authenticated user has
/// one or more leagues in.
public struct CDYahooGame: CDYahooXMLDecodable, Sendable, Equatable {
    public let gameKey: String
    public let gameId: String
    public let name: String
    public let code: String
    public let season: String
    public let leagues: [CDYahooLeagueSummary]

    public init(gameKey: String, gameId: String, name: String, code: String, season: String, leagues: [CDYahooLeagueSummary]) {
        self.gameKey = gameKey
        self.gameId = gameId
        self.name = name
        self.code = code
        self.season = season
        self.leagues = leagues
    }

    init(node: CDYahooXMLNode) throws {
        guard let gameKey = node.text("game_key"), let gameId = node.text("game_id"), let name = node.text("name"),
              let code = node.text("code"), let season = node.text("season") else {
            throw CDYahooXMLDecodingError.missingField("game")
        }
        self.gameKey = gameKey
        self.gameId = gameId
        self.name = name
        self.code = code
        self.season = season
        self.leagues = try node.child("leagues")?.children("league").map(CDYahooLeagueSummary.init(node:)) ?? []
    }
}
