//
//  CDYahooKeychainTests.swift
//  CDYahooKitTests
//

import Testing
@testable import CDYahooKit

@Suite("CDYahooKeychain")
struct CDYahooKeychainTests {

    @Test("set then string round-trips a value")
    func setThenStringRoundTrips() {
        let key = "CDYahooKeychainTests.roundTrip"
        defer { CDYahooKeychain.delete(forKey: key) }

        #expect(CDYahooKeychain.set("hello", forKey: key))
        #expect(CDYahooKeychain.string(forKey: key) == "hello")
    }

    @Test("set overwrites a previously stored value")
    func setOverwritesExistingValue() {
        let key = "CDYahooKeychainTests.overwrite"
        defer { CDYahooKeychain.delete(forKey: key) }

        #expect(CDYahooKeychain.set("first", forKey: key))
        #expect(CDYahooKeychain.set("second", forKey: key))
        #expect(CDYahooKeychain.string(forKey: key) == "second")
    }

    @Test("string returns nil for a key that was never set")
    func stringReturnsNilForMissingKey() {
        #expect(CDYahooKeychain.string(forKey: "CDYahooKeychainTests.neverSet") == nil)
    }

    @Test("delete removes a stored value")
    func deleteRemovesValue() {
        let key = "CDYahooKeychainTests.delete"
        #expect(CDYahooKeychain.set("value", forKey: key))
        #expect(CDYahooKeychain.delete(forKey: key))
        #expect(CDYahooKeychain.string(forKey: key) == nil)
    }
}
