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
        // Including the Authorization header means a cache entry is automatically invalidated
        // when a different access token is in play (different signed-in user, or a refreshed
        // token) — without needing explicit cache-clearing coordination with the OAuth client.
        let cacheKey = "\(adaptedRequest.url?.absoluteString ?? "")|\(adaptedRequest.value(forHTTPHeaderField: "Authorization") ?? "")"

        if isCacheable, let cachedData = await cache.data(forKey: cacheKey) {
            return try Self.decode(cachedData)
        }

        var attempt = 0
        while true {
            for monitor in eventMonitors {
                monitor.willSend(adaptedRequest)
            }
            do {
                return try await attemptOnce(adaptedRequest, isCacheable: isCacheable, cacheKey: cacheKey)
            } catch {
                let (thrown, isTransient) = Self.unwrap(error)
                for monitor in eventMonitors {
                    monitor.didReceive(nil, data: nil, error: thrown)
                }
                attempt += 1
                guard isTransient, attempt <= retryConfiguration.maximumRetryCount else { throw thrown }
                let delay = retryConfiguration.baseDelay * pow(2.0, Double(attempt - 1))
                // `try` (not `try?`) so a cancelled task's `CancellationError` propagates instead
                // of being swallowed, which would otherwise let the remaining retries fire back
                // to back after cancellation.
                try await Task.sleep(nanoseconds: UInt64(delay * 1_000_000_000))
            }
        }
    }

    /// Sends one request attempt, checks the HTTP status (surfacing Yahoo's `<error>` envelope on
    /// non-2xx before falling back to a generic `invalidRequest`), caches the body on success, and
    /// decodes it as `T`. Every thrown error is a `CDYahooAttemptFailure` tagged with whether
    /// `perform`'s retry loop should retry it.
    private func attemptOnce<T: CDYahooXMLDecodable>(_ request: URLRequest, isCacheable: Bool, cacheKey: String) async throws -> T {
        let (data, response) = try await session.data(for: request)
        guard let httpResponse = response as? HTTPURLResponse else {
            throw CDYahooKitError.invalidRequest(underlying: URLError(.badServerResponse))
        }
        for monitor in eventMonitors {
            monitor.didReceive(response, data: data, error: nil)
        }
        guard (200 ..< 300).contains(httpResponse.statusCode) else {
            throw Self.attemptFailure(forNon2xxResponse: httpResponse, data: data)
        }
        if isCacheable {
            await cache.store(data, forKey: cacheKey)
        }
        do {
            return try Self.decode(data)
        } catch {
            // A malformed/unexpected response body can never be fixed by retrying.
            throw CDYahooAttemptFailure(underlying: error, isTransient: false)
        }
    }

    /// Builds the error to throw for a non-2xx HTTP response, tagged with whether it's transient
    /// (safe to retry). Yahoo returns its `<error>` envelope WITH non-2xx status codes, so the
    /// body is parsed even on failure and its `<description>` is surfaced via `apiError` before
    /// falling back to a generic `invalidRequest`. An `apiError` is never transient — Yahoo is
    /// telling us definitively what's wrong, and retrying the same request won't change that —
    /// otherwise only 5xx/429 are treated as transient, since a 4xx can never succeed on retry.
    private static func attemptFailure(forNon2xxResponse httpResponse: HTTPURLResponse, data: Data) -> CDYahooAttemptFailure {
        if let node = try? CDYahooXMLTreeBuilder.parse(data), node.name == "error" {
            let underlying = CDYahooKitError.apiError(node.text("description") ?? "Yahoo Fantasy API returned an error.")
            return CDYahooAttemptFailure(underlying: underlying, isTransient: false)
        }
        let isTransient = httpResponse.statusCode == 429 || (500 ..< 600).contains(httpResponse.statusCode)
        let underlying = CDYahooKitError.invalidRequest(underlying: URLError(.badServerResponse))
        return CDYahooAttemptFailure(underlying: underlying, isTransient: isTransient)
    }

    /// Unwraps a caught error into the error to surface to the caller and whether the attempt
    /// that produced it is safe to retry. An error that isn't a `CDYahooAttemptFailure` came
    /// directly from `session.data(for:)` — a transport-level failure with no HTTP response at
    /// all — which is safe to retry.
    private static func unwrap(_ error: any Error) -> (thrown: any Error, isTransient: Bool) {
        if let failure = error as? CDYahooAttemptFailure {
            (failure.underlying, failure.isTransient)
        } else {
            (error, true)
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

/// Wraps an error thrown mid-attempt together with whether the retry loop should treat it as
/// transient (network/transport failures and HTTP 5xx/429) versus non-transient (4xx responses,
/// Yahoo's `<error>` envelope, or a malformed/undecodable body) — none of which can succeed by
/// simply retrying the same request.
private struct CDYahooAttemptFailure: Error {
    let underlying: any Error
    let isTransient: Bool
}
