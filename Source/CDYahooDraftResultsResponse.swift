//
//  CDYahooDraftResultsResponse.swift
//  CDYahooKit
//

/// One pick from a league's draft: which team took which player, and where in the draft.
///
/// `cost` is populated only for auction drafts; a snake draft omits it.
public struct CDYahooDraftResult: CDYahooXMLDecodable, Sendable, Equatable, Codable {
    public let pick: Int
    public let round: Int
    public let cost: Int?
    public let teamKey: String
    public let playerKey: String

    public init(pick: Int, round: Int, cost: Int?, teamKey: String, playerKey: String) {
        self.pick = pick
        self.round = round
        self.cost = cost
        self.teamKey = teamKey
        self.playerKey = playerKey
    }

    init(node: CDYahooXMLNode) throws {
        guard let pick = node.int("pick"), let round = node.int("round"),
              let teamKey = node.text("team_key"), let playerKey = node.text("player_key") else {
            throw CDYahooXMLDecodingError.missingField("draft_result")
        }
        self.pick = pick
        self.round = round
        self.cost = node.int("cost")
        self.teamKey = teamKey
        self.playerKey = playerKey
    }
}

/// The response from `league/{league_key}/draftresults` — every pick in the league's draft.
public struct CDYahooLeagueDraftResultsResponse: CDYahooXMLDecodable, Sendable, Equatable, Codable {
    public let leagueKey: String
    public let draftResults: [CDYahooDraftResult]

    public init(leagueKey: String, draftResults: [CDYahooDraftResult]) {
        self.leagueKey = leagueKey
        self.draftResults = draftResults
    }

    init(node: CDYahooXMLNode) throws {
        guard let leagueNode = node.child("league"), let leagueKey = leagueNode.text("league_key") else {
            throw CDYahooXMLDecodingError.missingField("league")
        }
        self.leagueKey = leagueKey
        let resultNodes = leagueNode.child("draft_results")?.children("draft_result") ?? []
        self.draftResults = try resultNodes.map(CDYahooDraftResult.init(node:))
    }
}

/// The response from `team/{team_key}/draftresults` — one team's picks from the league's draft.
public struct CDYahooTeamDraftResultsResponse: CDYahooXMLDecodable, Sendable, Equatable, Codable {
    public let teamKey: String
    public let draftResults: [CDYahooDraftResult]

    public init(teamKey: String, draftResults: [CDYahooDraftResult]) {
        self.teamKey = teamKey
        self.draftResults = draftResults
    }

    init(node: CDYahooXMLNode) throws {
        guard let teamNode = node.child("team"), let teamKey = teamNode.text("team_key") else {
            throw CDYahooXMLDecodingError.missingField("team")
        }
        self.teamKey = teamKey
        let resultNodes = teamNode.child("draft_results")?.children("draft_result") ?? []
        self.draftResults = try resultNodes.map(CDYahooDraftResult.init(node:))
    }
}
