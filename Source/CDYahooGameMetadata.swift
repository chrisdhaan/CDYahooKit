//
//  CDYahooGameMetadata.swift
//  CDYahooKit
//

/// A scoring stat a fantasy game defines, from `game/{game_key}/stat_categories`.
///
/// Unlike the league-scoped ``CDYahooStatCategory`` it carries no `enabled` flag — that is a
/// per-league setting — and lists the position types the stat applies to in `statPositionTypes`
/// (empty when Yahoo omits the element). `statId` joins to a league's ``CDYahooStatModifier`` for
/// the stat's point value.
public struct CDYahooGameStatCategory: CDYahooXMLDecodable, Sendable, Equatable, Codable {
    public let statId: Int
    public let name: String
    public let displayName: String?
    public let sortOrder: Int?
    public let positionType: String?
    public let statPositionTypes: [String]

    public init(statId: Int, name: String, displayName: String?, sortOrder: Int?, positionType: String?,
                statPositionTypes: [String]) {
        self.statId = statId
        self.name = name
        self.displayName = displayName
        self.sortOrder = sortOrder
        self.positionType = positionType
        self.statPositionTypes = statPositionTypes
    }

    init(node: CDYahooXMLNode) throws {
        guard let statId = node.int("stat_id"), let name = node.text("name") else {
            throw CDYahooXMLDecodingError.missingField("stat")
        }
        self.statId = statId
        self.name = name
        self.displayName = node.text("display_name")
        self.sortOrder = node.int("sort_order")
        self.positionType = node.text("position_type")
        self.statPositionTypes = (node.child("stat_position_types")?.children("stat_position_type") ?? [])
            .compactMap { $0.text("position_type") }
    }
}

/// The response from `game/{game_key}/stat_categories` — every stat the game scores.
public struct CDYahooGameStatCategoriesResponse: CDYahooXMLDecodable, Sendable, Equatable, Codable {
    public let gameKey: String
    public let statCategories: [CDYahooGameStatCategory]

    public init(gameKey: String, statCategories: [CDYahooGameStatCategory]) {
        self.gameKey = gameKey
        self.statCategories = statCategories
    }

    init(node: CDYahooXMLNode) throws {
        guard let gameNode = node.child("game"), let gameKey = gameNode.text("game_key") else {
            throw CDYahooXMLDecodingError.missingField("game")
        }
        self.gameKey = gameKey
        let statNodes = gameNode.child("stat_categories")?.child("stats")?.children("stat") ?? []
        self.statCategories = try statNodes.map(CDYahooGameStatCategory.init(node:))
    }
}

/// One player-position category a fantasy game defines, from `game/{game_key}/position_types`
/// (e.g. `O` / "Offense", `DT` / "Defense/Special Teams").
public struct CDYahooPositionType: CDYahooXMLDecodable, Sendable, Equatable, Codable {
    public let type: String
    public let displayName: String?

    public init(type: String, displayName: String?) {
        self.type = type
        self.displayName = displayName
    }

    init(node: CDYahooXMLNode) throws {
        guard let type = node.text("type") else {
            throw CDYahooXMLDecodingError.missingField("position_type")
        }
        self.type = type
        self.displayName = node.text("display_name")
    }
}

/// The response from `game/{game_key}/position_types`.
public struct CDYahooGamePositionTypesResponse: CDYahooXMLDecodable, Sendable, Equatable, Codable {
    public let gameKey: String
    public let positionTypes: [CDYahooPositionType]

    public init(gameKey: String, positionTypes: [CDYahooPositionType]) {
        self.gameKey = gameKey
        self.positionTypes = positionTypes
    }

    init(node: CDYahooXMLNode) throws {
        guard let gameNode = node.child("game"), let gameKey = gameNode.text("game_key") else {
            throw CDYahooXMLDecodingError.missingField("game")
        }
        self.gameKey = gameKey
        let typeNodes = gameNode.child("position_types")?.children("position_type") ?? []
        self.positionTypes = try typeNodes.map(CDYahooPositionType.init(node:))
    }
}

/// One roster slot a fantasy game defines, from `game/{game_key}/roster_positions`.
///
/// Unlike the league-scoped ``CDYahooRosterPosition`` it describes the position itself — its
/// abbreviation and display name — rather than how many of it a specific league starts.
/// `positionType` is absent for bench / injured-reserve slots.
public struct CDYahooGameRosterPosition: CDYahooXMLDecodable, Sendable, Equatable, Codable {
    public let position: String
    public let abbreviation: String?
    public let displayName: String?
    public let positionType: String?

    public init(position: String, abbreviation: String?, displayName: String?, positionType: String?) {
        self.position = position
        self.abbreviation = abbreviation
        self.displayName = displayName
        self.positionType = positionType
    }

    init(node: CDYahooXMLNode) throws {
        guard let position = node.text("position") else {
            throw CDYahooXMLDecodingError.missingField("roster_position")
        }
        self.position = position
        self.abbreviation = node.text("abbreviation")
        self.displayName = node.text("display_name")
        self.positionType = node.text("position_type")
    }
}

/// The response from `game/{game_key}/roster_positions`.
public struct CDYahooGameRosterPositionsResponse: CDYahooXMLDecodable, Sendable, Equatable, Codable {
    public let gameKey: String
    public let rosterPositions: [CDYahooGameRosterPosition]

    public init(gameKey: String, rosterPositions: [CDYahooGameRosterPosition]) {
        self.gameKey = gameKey
        self.rosterPositions = rosterPositions
    }

    init(node: CDYahooXMLNode) throws {
        guard let gameNode = node.child("game"), let gameKey = gameNode.text("game_key") else {
            throw CDYahooXMLDecodingError.missingField("game")
        }
        self.gameKey = gameKey
        let positionNodes = gameNode.child("roster_positions")?.children("roster_position") ?? []
        self.rosterPositions = try positionNodes.map(CDYahooGameRosterPosition.init(node:))
    }
}

/// One scoring period in a fantasy game's schedule, from `game/{game_key}/game_weeks` — the week
/// number and the `YYYY-MM-DD` calendar dates it spans.
public struct CDYahooGameWeek: CDYahooXMLDecodable, Sendable, Equatable, Codable {
    public let week: Int
    public let displayName: String?
    public let start: String?
    public let end: String?

    public init(week: Int, displayName: String?, start: String?, end: String?) {
        self.week = week
        self.displayName = displayName
        self.start = start
        self.end = end
    }

    init(node: CDYahooXMLNode) throws {
        guard let week = node.int("week") else {
            throw CDYahooXMLDecodingError.missingField("game_week")
        }
        self.week = week
        self.displayName = node.text("display_name")
        self.start = node.text("start")
        self.end = node.text("end")
    }
}

/// The response from `game/{game_key}/game_weeks`.
public struct CDYahooGameWeeksResponse: CDYahooXMLDecodable, Sendable, Equatable, Codable {
    public let gameKey: String
    public let gameWeeks: [CDYahooGameWeek]

    public init(gameKey: String, gameWeeks: [CDYahooGameWeek]) {
        self.gameKey = gameKey
        self.gameWeeks = gameWeeks
    }

    init(node: CDYahooXMLNode) throws {
        guard let gameNode = node.child("game"), let gameKey = gameNode.text("game_key") else {
            throw CDYahooXMLDecodingError.missingField("game")
        }
        self.gameKey = gameKey
        let weekNodes = gameNode.child("game_weeks")?.children("game_week") ?? []
        self.gameWeeks = try weekNodes.map(CDYahooGameWeek.init(node:))
    }
}
