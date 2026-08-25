//
//  CDYahooResponseCacheTests.swift
//  CDYahooKitTests
//

import Foundation
import Testing
@testable import CDYahooKit

@Suite("CDYahooResponseCache")
struct CDYahooResponseCacheTests {

    @Test("disabled configuration never stores or returns data")
    func disabledConfigurationStoresNothing() async {
        let cache = CDYahooResponseCache(configuration: .disabled)
        await cache.store(Data("hello".utf8), forKey: "key")
        #expect(await cache.data(forKey: "key") == nil)
    }

    @Test("enabled configuration round-trips stored data")
    func enabledConfigurationRoundTrips() async {
        let cache = CDYahooResponseCache(configuration: .enabled(maximumEntries: 10, timeToLive: 300))
        await cache.store(Data("hello".utf8), forKey: "key")
        #expect(await cache.data(forKey: "key") == Data("hello".utf8))
    }

    @Test("entries older than the time-to-live are treated as a miss")
    func expiredEntriesAreEvicted() async {
        let cache = CDYahooResponseCache(configuration: .enabled(maximumEntries: 10, timeToLive: 0))
        await cache.store(Data("hello".utf8), forKey: "key")
        try? await Task.sleep(nanoseconds: 10_000_000)
        #expect(await cache.data(forKey: "key") == nil)
    }
}
