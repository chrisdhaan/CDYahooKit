//
//  CDYahooCacheConfiguration.swift
//  CDYahooKit
//

import Foundation

/// Configures `CDYahooURLSession`'s opt-in in-memory response cache, applied to `GET` requests
/// only. Disabled by default.
public struct CDYahooCacheConfiguration: Sendable {
    public let isEnabled: Bool
    public let maximumEntries: Int
    public let timeToLive: TimeInterval

    public static let disabled = CDYahooCacheConfiguration(isEnabled: false, maximumEntries: 0, timeToLive: 0)

    public static func enabled(maximumEntries: Int = 100, timeToLive: TimeInterval = 300) -> CDYahooCacheConfiguration {
        CDYahooCacheConfiguration(isEnabled: true, maximumEntries: maximumEntries, timeToLive: timeToLive)
    }
}
