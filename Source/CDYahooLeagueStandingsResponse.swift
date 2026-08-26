//
//  CDYahooLeagueStandingsResponse.swift
//  CDYahooKit
//

/// A team's regular-season win/loss/tie record and points.
public struct CDYahooTeamOutcomeTotals: CDYahooXMLDecodable, Sendable, Equatable, Codable {
    public let wins: Int
    public let losses: Int
    public let ties: Int
    public let percentage: String

    public init(wins: Int, losses: Int, ties: Int, percentage: String) {
        self.wins = wins
        self.losses = losses
        self.ties = ties
        self.percentage = percentage
    }

    init(node: CDYahooXMLNode) throws {
        self.wins = node.int("wins") ?? 0
        self.losses = node.int("losses") ?? 0
        self.ties = node.int("ties") ?? 0
        self.percentage = node.text("percentage") ?? "0.000"
    }
}

/// One team's row in a league's standings.
public struct CDYahooTeamStanding: CDYahooXMLDecodable, Sendable, Equatable, Codable {
    public let teamKey: String
    public let teamId: String
    public let name: String
    public let rank: Int?
    public let outcomeTotals: CDYahooTeamOutcomeTotals?
    public let pointsFor: Double?
    public let pointsAgainst: Double?

    public init(teamKey: String, teamId: String, name: String, rank: Int?, outcomeTotals: CDYahooTeamOutcomeTotals?,
                pointsFor: Double?, pointsAgainst: Double?) {
        self.teamKey = teamKey
        self.teamId = teamId
        self.name = name
        self.rank = rank
        self.outcomeTotals = outcomeTotals
        self.pointsFor = pointsFor
        self.pointsAgainst = pointsAgainst
    }

    init(node: CDYahooXMLNode) throws {
        guard let teamKey = node.text("team_key"), let teamId = node.text("team_id"), let name = node.text("name") else {
            throw CDYahooXMLDecodingError.missingField("team")
        }
        self.teamKey = teamKey
        self.teamId = teamId
        self.name = name
        let standingsNode = node.child("team_standings")
        self.rank = standingsNode?.int("rank")
        self.outcomeTotals = try standingsNode?.child("outcome_totals").map(CDYahooTeamOutcomeTotals.init(node:))
        self.pointsFor = standingsNode?.text("points_for").flatMap(Double.init)
        self.pointsAgainst = standingsNode?.text("points_against").flatMap(Double.init)
    }
}

/// The response from `league/{league_key}/standings`.
public struct CDYahooLeagueStandingsResponse: CDYahooXMLDecodable, Sendable, Equatable, Codable {
    public let leagueKey: String
    public let teams: [CDYahooTeamStanding]

    public init(leagueKey: String, teams: [CDYahooTeamStanding]) {
        self.leagueKey = leagueKey
        self.teams = teams
    }

    init(node: CDYahooXMLNode) throws {
        guard let leagueNode = node.child("league"), let leagueKey = leagueNode.text("league_key") else {
            throw CDYahooXMLDecodingError.missingField("league")
        }
        self.leagueKey = leagueKey
        let teamNodes = leagueNode.child("standings")?.child("teams")?.children("team") ?? []
        self.teams = try teamNodes.map(CDYahooTeamStanding.init(node:))
    }
}
