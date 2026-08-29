//
//  CDYahooTeamMatchupsResponse.swift
//  CDYahooKit
//

/// The response from `team/{team_key}/matchups` (optionally `;weeks={w1},{w2},…`) — one team's
/// schedule of head-to-head matchups, each with both sides' scores.
///
/// Each entry is a ``CDYahooMatchup``, the same element the league ``CDYahooLeagueScoreboardResponse``
/// returns; the team `matchups` payload additionally populates its week-boundary and outcome fields.
public struct CDYahooTeamMatchupsResponse: CDYahooXMLDecodable, Sendable, Equatable, Codable {
    public let teamKey: String
    public let matchups: [CDYahooMatchup]

    public init(teamKey: String, matchups: [CDYahooMatchup]) {
        self.teamKey = teamKey
        self.matchups = matchups
    }

    init(node: CDYahooXMLNode) throws {
        guard let teamNode = node.child("team"), let teamKey = teamNode.text("team_key") else {
            throw CDYahooXMLDecodingError.missingField("team")
        }
        self.teamKey = teamKey
        let matchupNodes = teamNode.child("matchups")?.children("matchup") ?? []
        self.matchups = try matchupNodes.map(CDYahooMatchup.init(node:))
    }
}
