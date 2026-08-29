//
//  CDYahooTeamStatsResponse.swift
//  CDYahooKit
//

/// The window a `team/{team_key}/stats` request covers — the whole season, or a single week.
///
/// Maps to Yahoo's `;type=season` and `;type=week;week={week}` matrix parameters.
public enum CDYahooTeamStatsCoverage: Sendable, Equatable {
    case season
    case week(Int)

    /// The matrix-parameter suffix appended to the `stats` path segment.
    var pathModifier: String {
        switch self {
        case .season: ";type=season"
        case let .week(week): ";type=week;week=\(week)"
        }
    }
}

/// One accumulated stat for a team over a coverage window, from `team_stats/stats`. Its `statId`
/// joins to the league's ``CDYahooStatCategory`` for the stat's name and to ``CDYahooStatModifier``
/// for its point value.
///
/// `value` is kept as a `String`: Yahoo emits `-` for a stat with no value in the window, and
/// emits fractions in the leading-dot form (`.5`), both lossy to round-trip through `Double`.
public struct CDYahooTeamStat: CDYahooXMLDecodable, Sendable, Equatable, Codable {
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

/// A team's accumulated stats for one coverage window, plus the fantasy points they earned.
public struct CDYahooTeamStats: CDYahooXMLDecodable, Sendable, Equatable, Codable {
    public let coverageType: String?
    public let week: Int?
    public let stats: [CDYahooTeamStat]
    public let totalPoints: Double?

    public init(coverageType: String?, week: Int?, stats: [CDYahooTeamStat], totalPoints: Double?) {
        self.coverageType = coverageType
        self.week = week
        self.stats = stats
        self.totalPoints = totalPoints
    }

    init(node: CDYahooXMLNode) throws {
        let statsNode = node.child("team_stats")
        self.coverageType = statsNode?.text("coverage_type")
        self.week = statsNode?.int("week")
        let statNodes = statsNode?.child("stats")?.children("stat") ?? []
        self.stats = try statNodes.map(CDYahooTeamStat.init(node:))
        self.totalPoints = node.child("team_points")?.text("total").flatMap(Double.init)
    }
}

/// The response from `team/{team_key}/stats;type=season` or `;type=week;week={week}`.
public struct CDYahooTeamStatsResponse: CDYahooXMLDecodable, Sendable, Equatable, Codable {
    public let teamKey: String
    public let stats: CDYahooTeamStats

    public init(teamKey: String, stats: CDYahooTeamStats) {
        self.teamKey = teamKey
        self.stats = stats
    }

    init(node: CDYahooXMLNode) throws {
        guard let teamNode = node.child("team"), let teamKey = teamNode.text("team_key") else {
            throw CDYahooXMLDecodingError.missingField("team")
        }
        self.teamKey = teamKey
        self.stats = try CDYahooTeamStats(node: teamNode)
    }
}
