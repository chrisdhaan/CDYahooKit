//
//  CDYahooKitError.swift
//  CDYahooKit
//

import Foundation

/// Errors thrown by CDYahooKit's OAuth and Fantasy Sports API clients.
///
/// `@unchecked Sendable` because the `underlying: any Error` associated values aren't verifiably
/// `Sendable` at compile time — `any Error` erases the concrete type. In practice every error
/// stored here (`URLError`, `DecodingError`, `CDYahooXMLDecodingError`) is safe to share across
/// isolation domains, mirroring `CDYelpRouter`'s identical rationale.
public enum CDYahooKitError: Error, LocalizedError, @unchecked Sendable {
    case invalidCredentials(String)
    case invalidRequest(underlying: any Error)
    case xmlParsingFailed(underlying: any Error)
    case responseDecodingFailed(underlying: any Error)
    case apiError(String)
    case authorizationCancelled

    public var errorDescription: String? {
        switch self {
        case let .invalidCredentials(message):
            message
        case let .invalidRequest(underlying):
            "Invalid request: \(underlying.localizedDescription)"
        case let .xmlParsingFailed(underlying):
            "Failed to parse Yahoo Fantasy API XML: \(underlying.localizedDescription)"
        case let .responseDecodingFailed(underlying):
            "Failed to decode Yahoo response: \(underlying.localizedDescription)"
        case let .apiError(message):
            message
        case .authorizationCancelled:
            "The user cancelled the Sign In With Yahoo authorization flow."
        }
    }
}
