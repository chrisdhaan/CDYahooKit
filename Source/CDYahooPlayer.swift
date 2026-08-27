//
//  CDYahooPlayer.swift
//  CDYahooKit
//

/// A player, as they appear on a team roster or in a league's player pool.
public struct CDYahooPlayer: CDYahooXMLDecodable, Sendable, Equatable, Codable {
    public let playerKey: String
    public let playerId: String
    public let fullName: String
    public let editorialTeamAbbr: String?
    public let displayPosition: String?
    public let selectedPosition: String?
    public let status: String?

    public init(playerKey: String, playerId: String, fullName: String, editorialTeamAbbr: String?,
                displayPosition: String?, selectedPosition: String?, status: String?) {
        self.playerKey = playerKey
        self.playerId = playerId
        self.fullName = fullName
        self.editorialTeamAbbr = editorialTeamAbbr
        self.displayPosition = displayPosition
        self.selectedPosition = selectedPosition
        self.status = status
    }

    init(node: CDYahooXMLNode) throws {
        guard let playerKey = node.text("player_key"), let playerId = node.text("player_id"),
              let fullName = node.child("name")?.text("full") else {
            throw CDYahooXMLDecodingError.missingField("player")
        }
        self.playerKey = playerKey
        self.playerId = playerId
        self.fullName = fullName
        self.editorialTeamAbbr = node.text("editorial_team_abbr")
        self.displayPosition = node.text("display_position")
        self.selectedPosition = node.child("selected_position")?.text("position")
        self.status = node.text("status")
    }
}
