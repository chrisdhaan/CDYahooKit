//
//  CDYahooResponseCache.swift
//  CDYahooKit
//

import Foundation

/// An in-memory `GET` response cache. An `actor` so concurrent reads/writes from multiple
/// in-flight requests can't race on the backing dictionary.
actor CDYahooResponseCache {

    private struct Entry {
        let data: Data
        let storedAt: Date
    }

    private var storage: [String: Entry] = [:]
    private let configuration: CDYahooCacheConfiguration

    init(configuration: CDYahooCacheConfiguration) {
        self.configuration = configuration
    }

    func data(forKey key: String) -> Data? {
        guard configuration.isEnabled, let entry = storage[key] else { return nil }
        guard Date().timeIntervalSince(entry.storedAt) < configuration.timeToLive else {
            storage[key] = nil
            return nil
        }
        return entry.data
    }

    func store(_ data: Data, forKey key: String) {
        guard configuration.isEnabled else { return }
        if storage.count >= configuration.maximumEntries {
            storage.removeAll()
        }
        storage[key] = Entry(data: data, storedAt: Date())
    }
}
