//
//  CDYahooLeagueSettingsResponse.swift
//  CDYahooKit
//

/// One slot in a league's required roster shape (e.g. one `QB`, five `BN` bench spots).
public struct CDYahooRosterPosition: CDYahooXMLDecodable, Sendable, Equatable, Codable {
    public let position: String
    public let positionType: String?
    public let count: Int

    public init(position: String, positionType: String?, count: Int) {
        self.position = position
        self.positionType = positionType
        self.count = count
    }

    init(node: CDYahooXMLNode) throws {
        guard let position = node.text("position") else {
            throw CDYahooXMLDecodingError.missingField("roster_position")
        }
        self.position = position
        self.positionType = node.text("position_type")
        self.count = node.int("count") ?? 0
    }
}

/// A scoring stat the league tracks, from `stat_categories`. Its point value, when the league
/// assigns one, is the matching ``CDYahooStatModifier`` by `statId`.
public struct CDYahooStatCategory: CDYahooXMLDecodable, Sendable, Equatable, Codable {
    public let statId: Int
    public let name: String
    public let displayName: String?
    public let enabled: Bool
    public let sortOrder: Int?
    public let positionType: String?

    public init(statId: Int, name: String, displayName: String?, enabled: Bool, sortOrder: Int?, positionType: String?) {
        self.statId = statId
        self.name = name
        self.displayName = displayName
        self.enabled = enabled
        self.sortOrder = sortOrder
        self.positionType = positionType
    }

    init(node: CDYahooXMLNode) throws {
        guard let statId = node.int("stat_id"), let name = node.text("name") else {
            throw CDYahooXMLDecodingError.missingField("stat")
        }
        self.statId = statId
        self.name = name
        self.displayName = node.text("display_name")
        self.enabled = node.bool("enabled") ?? true
        self.sortOrder = node.int("sort_order")
        self.positionType = node.text("position_type")
    }
}

/// The points a league awards per unit of a stat, from `stat_modifiers`. Joins to
/// ``CDYahooStatCategory`` on `statId`.
public struct CDYahooStatModifier: CDYahooXMLDecodable, Sendable, Equatable, Codable {
    public let statId: Int
    public let value: Double

    public init(statId: Int, value: Double) {
        self.statId = statId
        self.value = value
    }

    init(node: CDYahooXMLNode) throws {
        guard let statId = node.int("stat_id"), let value = node.text("value").flatMap(Double.init) else {
            throw CDYahooXMLDecodingError.missingField("stat")
        }
        self.statId = statId
        self.value = value
    }
}

/// A league's configuration: how it scores, the roster it requires, the stats it tracks and
/// their point values, and its waiver, trade, and playoff rules.
///
/// Every field is optional in the decoder — a settings response for a league that hasn't drafted,
/// or one from a sport whose settings omit a rule, still decodes.
public struct CDYahooLeagueSettings: CDYahooXMLDecodable, Sendable, Equatable, Codable {
    public let scoringType: String?
    public let usesPlayoff: Bool?
    public let playoffStartWeek: Int?
    public let numPlayoffTeams: Int?
    public let numPlayoffConsolationTeams: Int?
    public let usesPlayoffReseeding: Bool?
    public let waiverType: String?
    public let waiverRule: String?
    public let usesFaab: Bool?
    public let waiverTime: Int?
    public let tradeEndDate: String?
    public let tradeRatifyType: String?
    public let tradeRejectTime: Int?
    public let rosterPositions: [CDYahooRosterPosition]
    public let statCategories: [CDYahooStatCategory]
    public let statModifiers: [CDYahooStatModifier]

    public init(scoringType: String?, usesPlayoff: Bool?, playoffStartWeek: Int?, numPlayoffTeams: Int?,
                numPlayoffConsolationTeams: Int?, usesPlayoffReseeding: Bool?, waiverType: String?, waiverRule: String?,
                usesFaab: Bool?, waiverTime: Int?, tradeEndDate: String?, tradeRatifyType: String?, tradeRejectTime: Int?,
                rosterPositions: [CDYahooRosterPosition], statCategories: [CDYahooStatCategory],
                statModifiers: [CDYahooStatModifier]) {
        self.scoringType = scoringType
        self.usesPlayoff = usesPlayoff
        self.playoffStartWeek = playoffStartWeek
        self.numPlayoffTeams = numPlayoffTeams
        self.numPlayoffConsolationTeams = numPlayoffConsolationTeams
        self.usesPlayoffReseeding = usesPlayoffReseeding
        self.waiverType = waiverType
        self.waiverRule = waiverRule
        self.usesFaab = usesFaab
        self.waiverTime = waiverTime
        self.tradeEndDate = tradeEndDate
        self.tradeRatifyType = tradeRatifyType
        self.tradeRejectTime = tradeRejectTime
        self.rosterPositions = rosterPositions
        self.statCategories = statCategories
        self.statModifiers = statModifiers
    }

    init(node: CDYahooXMLNode) throws {
        self.scoringType = node.text("scoring_type")
        self.usesPlayoff = node.bool("uses_playoff")
        self.playoffStartWeek = node.int("playoff_start_week")
        self.numPlayoffTeams = node.int("num_playoff_teams")
        self.numPlayoffConsolationTeams = node.int("num_playoff_consolation_teams")
        self.usesPlayoffReseeding = node.bool("uses_playoff_reseeding")
        self.waiverType = node.text("waiver_type")
        self.waiverRule = node.text("waiver_rule")
        self.usesFaab = node.bool("uses_faab")
        self.waiverTime = node.int("waiver_time")
        self.tradeEndDate = node.text("trade_end_date")
        self.tradeRatifyType = node.text("trade_ratify_type")
        self.tradeRejectTime = node.int("trade_reject_time")
        let rosterPositionNodes = node.child("roster_positions")?.children("roster_position") ?? []
        self.rosterPositions = try rosterPositionNodes.map(CDYahooRosterPosition.init(node:))
        let statNodes = node.child("stat_categories")?.child("stats")?.children("stat") ?? []
        self.statCategories = try statNodes.map(CDYahooStatCategory.init(node:))
        let modifierNodes = node.child("stat_modifiers")?.child("stats")?.children("stat") ?? []
        self.statModifiers = try modifierNodes.map(CDYahooStatModifier.init(node:))
    }
}

/// The response from `league/{league_key}/settings`.
public struct CDYahooLeagueSettingsResponse: CDYahooXMLDecodable, Sendable, Equatable, Codable {
    public let leagueKey: String
    public let settings: CDYahooLeagueSettings

    public init(leagueKey: String, settings: CDYahooLeagueSettings) {
        self.leagueKey = leagueKey
        self.settings = settings
    }

    init(node: CDYahooXMLNode) throws {
        guard let leagueNode = node.child("league"), let leagueKey = leagueNode.text("league_key"),
              let settingsNode = leagueNode.child("settings") else {
            throw CDYahooXMLDecodingError.missingField("league/settings")
        }
        self.leagueKey = leagueKey
        self.settings = try CDYahooLeagueSettings(node: settingsNode)
    }
}
