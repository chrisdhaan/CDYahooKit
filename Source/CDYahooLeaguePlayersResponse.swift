//
//  CDYahooLeaguePlayersResponse.swift
//  CDYahooKit
//

/// The response from `league/{league_key}/players` (optionally `;start={start}` for pagination).
public struct CDYahooLeaguePlayersResponse: CDYahooXMLDecodable, Sendable {
    public let leagueKey: String
    public let players: [CDYahooPlayer]

    init(node: CDYahooXMLNode) throws {
        guard let leagueNode = node.child("league"), let leagueKey = leagueNode.text("league_key") else {
            throw CDYahooXMLDecodingError.missingField("league")
        }
        self.leagueKey = leagueKey
        let playerNodes = leagueNode.child("players")?.children("player") ?? []
        self.players = try playerNodes.map(CDYahooPlayer.init(node:))
    }
}
