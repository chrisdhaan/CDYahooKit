//
//  CDYahooLeague.swift
//  CDYahooKit
//

/// A fantasy league's metadata and settings.
public struct CDYahooLeague: CDYahooXMLDecodable, Sendable, Equatable, Codable {
    public let leagueKey: String
    public let leagueId: String
    public let name: String
    public let url: String?
    public let numTeams: Int?
    public let scoringType: String?
    public let currentWeek: Int?
    public let season: String?

    public init(leagueKey: String, leagueId: String, name: String, url: String?, numTeams: Int?,
                scoringType: String?, currentWeek: Int?, season: String?) {
        self.leagueKey = leagueKey
        self.leagueId = leagueId
        self.name = name
        self.url = url
        self.numTeams = numTeams
        self.scoringType = scoringType
        self.currentWeek = currentWeek
        self.season = season
    }

    init(node: CDYahooXMLNode) throws {
        guard let leagueKey = node.text("league_key"), let leagueId = node.text("league_id"), let name = node.text("name") else {
            throw CDYahooXMLDecodingError.missingField("league")
        }
        self.leagueKey = leagueKey
        self.leagueId = leagueId
        self.name = name
        self.url = node.text("url")
        self.numTeams = node.int("num_teams")
        self.scoringType = node.text("scoring_type")
        self.currentWeek = node.int("current_week")
        self.season = node.text("season")
    }
}
