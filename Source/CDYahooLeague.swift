//
//  CDYahooLeague.swift
//  CDYahooKit
//

/// A fantasy league's metadata and settings.
public struct CDYahooLeague: CDYahooXMLDecodable, Sendable, Equatable {
    public let leagueKey: String
    public let leagueId: String
    public let name: String
    public let url: String?
    public let numTeams: Int?
    public let scoringType: String?
    public let currentWeek: Int?
    public let season: String?

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
