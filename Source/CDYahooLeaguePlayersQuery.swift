//
//  CDYahooLeaguePlayersQuery.swift
//  CDYahooKit
//

import Foundation

/// Which optional per-player sub-resources to pull alongside the base player pool, mapped to
/// Yahoo's `;out=` selector (`stats`, `percent_owned`, `ownership`). Combine with set syntax;
/// the selected values are emitted as one comma-joined `;out=` parameter.
public struct CDYahooPlayerSubresource: OptionSet, Sendable {
    public let rawValue: Int

    public init(rawValue: Int) {
        self.rawValue = rawValue
    }

    /// Season stat totals — decodes to ``CDYahooPlayer/stats``.
    public static let stats = CDYahooPlayerSubresource(rawValue: 1 << 0)
    /// League-wide roster ownership percentage — decodes to ``CDYahooPlayer/percentOwned``.
    public static let percentOwned = CDYahooPlayerSubresource(rawValue: 1 << 1)
    /// Who currently holds the player — decodes to ``CDYahooPlayer/ownership``.
    public static let ownership = CDYahooPlayerSubresource(rawValue: 1 << 2)

    /// The comma-joined value for the `;out=` parameter, in a fixed order.
    var outValue: String {
        var codes: [String] = []
        if contains(.stats) {
            codes.append("stats")
        }
        if contains(.percentOwned) {
            codes.append("percent_owned")
        }
        if contains(.ownership) {
            codes.append("ownership")
        }
        return codes.joined(separator: ",")
    }
}

/// The availability filter for a league-players request, mapped to Yahoo's `;status=` codes.
public enum CDYahooPlayerStatusFilter: Sendable, Equatable {
    /// Every player (`A`).
    case available
    /// Free agents only (`FA`).
    case freeAgents
    /// Players currently on waivers (`W`).
    case waivers
    /// Players on a team's roster (`T`).
    case taken
    /// Designated keepers (`K`).
    case keepers

    var code: String {
        switch self {
        case .available: "A"
        case .freeAgents: "FA"
        case .waivers: "W"
        case .taken: "T"
        case .keepers: "K"
        }
    }
}

/// The sort order for a league-players request, mapped to Yahoo's `;sort=` codes. Pass
/// ``stat(_:)`` with a stat id to sort by that stat.
public enum CDYahooPlayersSort: Sendable, Equatable {
    /// Alphabetical by name (`NAME`).
    case name
    /// Yahoo's overall preseason rank (`OR`).
    case overallRank
    /// Season-to-date actual rank (`AR`).
    case actualRank
    /// Total fantasy points (`PTS`).
    case points
    /// A specific stat, by its `stat_id`.
    case stat(Int)

    var code: String {
        switch self {
        case .name: "NAME"
        case .overallRank: "OR"
        case .actualRank: "AR"
        case .points: "PTS"
        case let .stat(id): String(id)
        }
    }
}

/// The collection modifiers for `league/{league_key}/players`: which sub-resources to include,
/// how to filter the pool, how to sort it, and how to page through it. Every field is optional;
/// a default-initialized query returns Yahoo's first unfiltered page.
///
/// The fields map to Yahoo matrix parameters appended to the `players` path segment, emitted in
/// a stable order: `;out=`, `;position=`, `;status=`, `;search=`, `;sort=`, `;start=`, `;count=`.
public struct CDYahooLeaguePlayersQuery: Sendable, Equatable {
    /// Optional per-player sub-resources (`;out=`).
    public var subresources: CDYahooPlayerSubresource
    /// Restrict to a single position code, e.g. `"QB"` (`;position=`).
    public var position: String?
    /// Restrict by availability (`;status=`).
    public var status: CDYahooPlayerStatusFilter?
    /// Case-insensitive name substring (`;search=`). Percent-encoded before it reaches the URL.
    public var search: String?
    /// Sort order (`;sort=`).
    public var sort: CDYahooPlayersSort?
    /// Zero-based offset into the pool (`;start=`).
    public var start: Int?
    /// Page size, capped by Yahoo at 25 (`;count=`).
    public var count: Int?

    public init(subresources: CDYahooPlayerSubresource = [], position: String? = nil,
                status: CDYahooPlayerStatusFilter? = nil, search: String? = nil,
                sort: CDYahooPlayersSort? = nil, start: Int? = nil, count: Int? = nil) {
        self.subresources = subresources
        self.position = position
        self.status = status
        self.search = search
        self.sort = sort
        self.start = start
        self.count = count
    }

    /// The matrix-parameter suffix appended to the `players` path segment — `""` when no
    /// modifier is set, otherwise a leading-`;` list in the documented order.
    var pathModifier: String {
        var parts: [String] = []
        if !subresources.isEmpty {
            parts.append("out=\(subresources.outValue)")
        }
        if let position {
            parts.append("position=\(position)")
        }
        if let status {
            parts.append("status=\(status.code)")
        }
        if let search {
            parts.append("search=\(Self.percentEncoded(search))")
        }
        if let sort {
            parts.append("sort=\(sort.code)")
        }
        if let start {
            parts.append("start=\(start)")
        }
        if let count {
            parts.append("count=\(count)")
        }
        return parts.isEmpty ? "" : ";" + parts.joined(separator: ";")
    }

    /// Percent-encodes a matrix-parameter value (allowed set: alphanumerics + `-._~`) so a value
    /// containing a space, `;`, `=`, or `/` can't silently reshape the URL.
    private static func percentEncoded(_ value: String) -> String {
        var allowed = CharacterSet.alphanumerics
        allowed.insert(charactersIn: "-._~")
        return value.addingPercentEncoding(withAllowedCharacters: allowed) ?? value
    }
}
