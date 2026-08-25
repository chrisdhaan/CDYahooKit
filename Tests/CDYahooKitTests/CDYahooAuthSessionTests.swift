//
//  CDYahooAuthSessionTests.swift
//  CDYahooKitTests
//

import AuthenticationServices
import Foundation
import Testing
@testable import CDYahooKit

@Suite("CDYahooAuthSession")
struct CDYahooAuthSessionTests {

    @Test("mapCallback returns the callback URL when there's no error")
    func mapCallbackReturnsURL() throws {
        let url = URL(string: "myapp://callback?code=abc&state=xyz")!
        #expect(try CDYahooAuthSession.mapCallback(url: url, error: nil) == url)
    }

    @Test("mapCallback throws authorizationCancelled for a cancelled login")
    func mapCallbackThrowsOnCancellation() throws {
        let error = ASWebAuthenticationSessionError(.canceledLogin)
        let thrown = try #require(throws: CDYahooKitError.self) {
            _ = try CDYahooAuthSession.mapCallback(url: nil, error: error)
        }
        guard case .authorizationCancelled = thrown else {
            Issue.record("Expected .authorizationCancelled, got \(thrown)")
            return
        }
    }

    @Test("mapCallback throws responseDecodingFailed when both url and error are nil")
    func mapCallbackThrowsWhenBothNil() {
        #expect(throws: CDYahooKitError.self) {
            _ = try CDYahooAuthSession.mapCallback(url: nil, error: nil)
        }
    }

    @Test("extractCode returns the code when state matches")
    func extractCodeReturnsCodeOnMatchingState() throws {
        let url = URL(string: "myapp://callback?code=abc123&state=xyz")!
        #expect(try CDYahooAuthSession.extractCode(from: url, expectedState: "xyz") == "abc123")
    }

    @Test("extractCode throws invalidCredentials when state doesn't match")
    func extractCodeThrowsOnStateMismatch() {
        let url = URL(string: "myapp://callback?code=abc123&state=wrong")!
        #expect(throws: CDYahooKitError.self) {
            _ = try CDYahooAuthSession.extractCode(from: url, expectedState: "xyz")
        }
    }

    @Test("extractCode throws invalidCredentials when the code is missing")
    func extractCodeThrowsWhenCodeMissing() {
        let url = URL(string: "myapp://callback?state=xyz")!
        #expect(throws: CDYahooKitError.self) {
            _ = try CDYahooAuthSession.extractCode(from: url, expectedState: "xyz")
        }
    }
}
