//
//  CDYahooLeagueScoreboardResponse.swift
//  CDYahooKit
//

/// One team's score within a `CDYahooMatchup`.
public struct CDYahooMatchupTeamScore: CDYahooXMLDecodable, Sendable, Equatable, Codable {
    public let teamKey: String
    public let name: String
    public let totalPoints: Double?
    /// The team's projected total for the matchup. Present in a team's `matchups` sub-resource;
    /// absent from the league `scoreboard`, where it decodes to `nil`.
    public let projectedPoints: Double?

    public init(teamKey: String, name: String, totalPoints: Double?, projectedPoints: Double? = nil) {
        self.teamKey = teamKey
        self.name = name
        self.totalPoints = totalPoints
        self.projectedPoints = projectedPoints
    }

    init(node: CDYahooXMLNode) throws {
        guard let teamKey = node.text("team_key"), let name = node.text("name") else {
            throw CDYahooXMLDecodingError.missingField("team")
        }
        self.teamKey = teamKey
        self.name = name
        self.totalPoints = node.child("team_points")?.text("total").flatMap(Double.init)
        self.projectedPoints = node.child("team_projected_points")?.text("total").flatMap(Double.init)
    }
}

/// One head-to-head matchup for a given week.
///
/// The league `scoreboard` and a team's `matchups` sub-resource both return this element. The
/// week-boundary and outcome fields (`weekStart` … `winnerTeamKey`) are populated from the
/// richer `matchups` payload and decode to `nil` in the leaner `scoreboard` one.
public struct CDYahooMatchup: CDYahooXMLDecodable, Sendable, Equatable, Codable {
    public let week: Int
    public let status: String
    public let weekStart: String?
    public let weekEnd: String?
    public let isPlayoffs: Bool?
    public let isConsolation: Bool?
    public let isTied: Bool?
    public let winnerTeamKey: String?
    public let teams: [CDYahooMatchupTeamScore]

    public init(week: Int, status: String, weekStart: String? = nil, weekEnd: String? = nil,
                isPlayoffs: Bool? = nil, isConsolation: Bool? = nil, isTied: Bool? = nil,
                winnerTeamKey: String? = nil, teams: [CDYahooMatchupTeamScore]) {
        self.week = week
        self.status = status
        self.weekStart = weekStart
        self.weekEnd = weekEnd
        self.isPlayoffs = isPlayoffs
        self.isConsolation = isConsolation
        self.isTied = isTied
        self.winnerTeamKey = winnerTeamKey
        self.teams = teams
    }

    init(node: CDYahooXMLNode) throws {
        self.week = node.int("week") ?? 0
        self.status = node.text("status") ?? ""
        self.weekStart = node.text("week_start")
        self.weekEnd = node.text("week_end")
        self.isPlayoffs = node.bool("is_playoffs")
        self.isConsolation = node.bool("is_consolation")
        self.isTied = node.bool("is_tied")
        self.winnerTeamKey = node.text("winner_team_key")
        let teamNodes = node.child("teams")?.children("team") ?? []
        self.teams = try teamNodes.map(CDYahooMatchupTeamScore.init(node:))
    }
}

/// The response from `league/{league_key}/scoreboard` (optionally `;week={week}`).
public struct CDYahooLeagueScoreboardResponse: CDYahooXMLDecodable, Sendable, Equatable, Codable {
    public let leagueKey: String
    public let matchups: [CDYahooMatchup]

    public init(leagueKey: String, matchups: [CDYahooMatchup]) {
        self.leagueKey = leagueKey
        self.matchups = matchups
    }

    init(node: CDYahooXMLNode) throws {
        guard let leagueNode = node.child("league"), let leagueKey = leagueNode.text("league_key") else {
            throw CDYahooXMLDecodingError.missingField("league")
        }
        self.leagueKey = leagueKey
        let matchupNodes = leagueNode.child("scoreboard")?.child("matchups")?.children("matchup") ?? []
        self.matchups = try matchupNodes.map(CDYahooMatchup.init(node:))
    }
}
