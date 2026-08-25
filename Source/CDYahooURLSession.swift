//
//  CDYahooURLSession.swift
//  CDYahooKit
//

import Foundation

/// Sends requests, applies caching/retry/adapters/monitors, and decodes the XML response body
/// into a `CDYahooXMLDecodable` type. Every public client (`CDYahooOAuthClient`,
/// `CDYahooFantasyAPIClient`) is built around one of these.
final class CDYahooURLSession: Sendable {

    private let session: URLSession
    private let cache: CDYahooResponseCache
    private let retryConfiguration: CDYahooRetryConfiguration
    private let eventMonitors: [any CDYahooEventMonitor]
    private let requestAdapters: [any CDYahooRequestAdapter]

    init(session: URLSession,
         retryConfiguration: CDYahooRetryConfiguration = .disabled,
         eventMonitors: [any CDYahooEventMonitor] = [],
         requestAdapters: [any CDYahooRequestAdapter] = [],
         cacheConfiguration: CDYahooCacheConfiguration = .disabled) {
        self.session = session
        self.retryConfiguration = retryConfiguration
        self.eventMonitors = eventMonitors
        self.requestAdapters = requestAdapters
        self.cache = CDYahooResponseCache(configuration: cacheConfiguration)
    }

    func perform<T: CDYahooXMLDecodable>(_ request: URLRequest) async throws -> T {
        var adaptedRequest = request
        for adapter in requestAdapters {
            adaptedRequest = adapter.adapt(adaptedRequest)
        }

        let isCacheable = adaptedRequest.httpMethod == nil || adaptedRequest.httpMethod == "GET"
        let cacheKey = adaptedRequest.url?.absoluteString ?? ""

        if isCacheable, let cachedData = await cache.data(forKey: cacheKey) {
            return try Self.decode(cachedData)
        }

        var attempt = 0
        while true {
            for monitor in eventMonitors { monitor.willSend(adaptedRequest) }
            do {
                let (data, response) = try await session.data(for: adaptedRequest)
                guard let httpResponse = response as? HTTPURLResponse, (200..<300).contains(httpResponse.statusCode) else {
                    throw CDYahooKitError.invalidRequest(underlying: URLError(.badServerResponse))
                }
                for monitor in eventMonitors { monitor.didReceive(response, data: data, error: nil) }
                if isCacheable {
                    await cache.store(data, forKey: cacheKey)
                }
                return try Self.decode(data)
            } catch {
                for monitor in eventMonitors { monitor.didReceive(nil, data: nil, error: error) }
                attempt += 1
                guard attempt <= retryConfiguration.maximumRetryCount else { throw error }
                let delay = retryConfiguration.baseDelay * pow(2.0, Double(attempt - 1))
                try? await Task.sleep(nanoseconds: UInt64(delay * 1_000_000_000))
            }
        }
    }

    /// Parses `data` and decodes it as `T` — unless the root element is Yahoo's `<error>`
    /// envelope, in which case this throws `CDYahooKitError.apiError` with its `<description>`
    /// instead of trying (and failing) to decode it as `T`. Every Fantasy Sports API response
    /// passes through here, so this is the single place that check needs to live.
    private static func decode<T: CDYahooXMLDecodable>(_ data: Data) throws -> T {
        let root = try CDYahooXMLTreeBuilder.parse(data)
        if root.name == "error" {
            throw CDYahooKitError.apiError(root.text("description") ?? "Yahoo Fantasy API returned an error.")
        }
        return try T(node: root)
    }
}
