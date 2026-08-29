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
    /// League-wide roster ownership percentage. Non-`nil` only when the request asked for the
    /// ``CDYahooPlayerSubresource/percentOwned`` sub-resource.
    public let percentOwned: Double?
    /// Who currently holds the player. Non-`nil` only when the request asked for the
    /// ``CDYahooPlayerSubresource/ownership`` sub-resource.
    public let ownership: CDYahooPlayerOwnership?
    /// The player's accumulated stats for the coverage window. Non-`nil` only when the request
    /// asked for the ``CDYahooPlayerSubresource/stats`` sub-resource.
    public let stats: [CDYahooPlayerStat]?

    public init(playerKey: String, playerId: String, fullName: String, editorialTeamAbbr: String?,
                displayPosition: String?, selectedPosition: String?, status: String?,
                percentOwned: Double? = nil, ownership: CDYahooPlayerOwnership? = nil,
                stats: [CDYahooPlayerStat]? = nil) {
        self.playerKey = playerKey
        self.playerId = playerId
        self.fullName = fullName
        self.editorialTeamAbbr = editorialTeamAbbr
        self.displayPosition = displayPosition
        self.selectedPosition = selectedPosition
        self.status = status
        self.percentOwned = percentOwned
        self.ownership = ownership
        self.stats = stats
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
        self.percentOwned = node.child("percent_owned")?.text("value").flatMap(Double.init)
        self.ownership = try node.child("ownership").map(CDYahooPlayerOwnership.init(node:))
        if let statNodes = node.child("player_stats")?.child("stats")?.children("stat") {
            self.stats = try statNodes.map(CDYahooPlayerStat.init(node:))
        } else {
            self.stats = nil
        }
    }
}

/// Who currently holds a player in a league, from the `;out=ownership` sub-resource.
public struct CDYahooPlayerOwnership: CDYahooXMLDecodable, Sendable, Equatable, Codable {
    /// Yahoo's ownership category, e.g. `"team"`, `"freeagents"`, `"waivers"`.
    public let ownershipType: String
    /// The owning team's key, when `ownershipType` is `"team"`.
    public let ownerTeamKey: String?
    /// The owning team's name, when `ownershipType` is `"team"`.
    public let ownerTeamName: String?

    public init(ownershipType: String, ownerTeamKey: String?, ownerTeamName: String?) {
        self.ownershipType = ownershipType
        self.ownerTeamKey = ownerTeamKey
        self.ownerTeamName = ownerTeamName
    }

    init(node: CDYahooXMLNode) throws {
        guard let ownershipType = node.text("ownership_type") else {
            throw CDYahooXMLDecodingError.missingField("ownership")
        }
        self.ownershipType = ownershipType
        self.ownerTeamKey = node.text("owner_team_key")
        self.ownerTeamName = node.text("owner_team_name")
    }
}

/// One accumulated stat for a player over a coverage window, from the `;out=stats` sub-resource.
/// Its `statId` joins to the league's ``CDYahooStatCategory`` for the stat's name. `value` is
/// kept as a `String` for the same reasons as ``CDYahooTeamStat/value``.
public struct CDYahooPlayerStat: CDYahooXMLDecodable, Sendable, Equatable, Codable {
    public let statId: Int
    public let value: String

    public init(statId: Int, value: String) {
        self.statId = statId
        self.value = value
    }

    init(node: CDYahooXMLNode) throws {
        guard let statId = node.int("stat_id"), let value = node.text("value") else {
            throw CDYahooXMLDecodingError.missingField("stat")
        }
        self.statId = statId
        self.value = value
    }
}
