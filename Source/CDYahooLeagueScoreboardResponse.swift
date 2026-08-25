//
//  CDYahooLeagueScoreboardResponse.swift
//  CDYahooKit
//

/// One team's score within a `CDYahooMatchup`.
public struct CDYahooMatchupTeamScore: CDYahooXMLDecodable, Sendable, Equatable {
    public let teamKey: String
    public let name: String
    public let totalPoints: Double?

    init(node: CDYahooXMLNode) throws {
        guard let teamKey = node.text("team_key"), let name = node.text("name") else {
            throw CDYahooXMLDecodingError.missingField("team")
        }
        self.teamKey = teamKey
        self.name = name
        self.totalPoints = node.child("team_points")?.text("total").flatMap(Double.init)
    }
}

/// One head-to-head matchup for a given week.
public struct CDYahooMatchup: CDYahooXMLDecodable, Sendable, Equatable {
    public let week: Int
    public let status: String
    public let teams: [CDYahooMatchupTeamScore]

    init(node: CDYahooXMLNode) throws {
        self.week = node.int("week") ?? 0
        self.status = node.text("status") ?? ""
        let teamNodes = node.child("teams")?.children("team") ?? []
        self.teams = try teamNodes.map(CDYahooMatchupTeamScore.init(node:))
    }
}

/// The response from `league/{league_key}/scoreboard` (optionally `;week={week}`).
public struct CDYahooLeagueScoreboardResponse: CDYahooXMLDecodable, Sendable {
    public let leagueKey: String
    public let matchups: [CDYahooMatchup]

    init(node: CDYahooXMLNode) throws {
        guard let leagueNode = node.child("league"), let leagueKey = leagueNode.text("league_key") else {
            throw CDYahooXMLDecodingError.missingField("league")
        }
        self.leagueKey = leagueKey
        let matchupNodes = leagueNode.child("scoreboard")?.child("matchups")?.children("matchup") ?? []
        self.matchups = try matchupNodes.map(CDYahooMatchup.init(node:))
    }
}
