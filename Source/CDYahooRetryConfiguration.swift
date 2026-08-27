//
//  CDYahooRetryConfiguration.swift
//  CDYahooKit
//

import Foundation

/// Configures `CDYahooURLSession`'s automatic retry with exponential backoff on transient
/// failures. Disabled by default.
public struct CDYahooRetryConfiguration: Sendable {
    public let maximumRetryCount: Int
    public let baseDelay: TimeInterval

    public static let disabled = CDYahooRetryConfiguration(maximumRetryCount: 0, baseDelay: 0)

    public static func enabled(maximumRetryCount: Int = 3, baseDelay: TimeInterval = 0.5) -> CDYahooRetryConfiguration {
        CDYahooRetryConfiguration(maximumRetryCount: maximumRetryCount, baseDelay: baseDelay)
    }
}
