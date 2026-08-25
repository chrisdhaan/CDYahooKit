//
//  CDYahooTeamRosterResponse.swift
//  CDYahooKit
//

/// The response from `team/{team_key}/roster` (optionally `;week={week}`).
public struct CDYahooTeamRosterResponse: CDYahooXMLDecodable, Sendable {
    public let teamKey: String
    public let name: String
    public let players: [CDYahooPlayer]

    init(node: CDYahooXMLNode) throws {
        guard let teamNode = node.child("team"), let teamKey = teamNode.text("team_key"), let name = teamNode.text("name") else {
            throw CDYahooXMLDecodingError.missingField("team")
        }
        self.teamKey = teamKey
        self.name = name
        let playerNodes = teamNode.child("roster")?.child("players")?.children("player") ?? []
        self.players = try playerNodes.map(CDYahooPlayer.init(node:))
    }
}
