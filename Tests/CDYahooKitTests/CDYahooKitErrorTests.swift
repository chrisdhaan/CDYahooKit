//
//  CDYahooKitErrorTests.swift
//  CDYahooKitTests
//

import Testing
@testable import CDYahooKit

@Suite("CDYahooKitError")
struct CDYahooKitErrorTests {

    @Test("apiError carries its message as the error description")
    func apiErrorDescription() {
        let error = CDYahooKitError.apiError("League not found")
        #expect(error.errorDescription == "League not found")
    }

    @Test("authorizationCancelled has a fixed description")
    func authorizationCancelledDescription() {
        let error = CDYahooKitError.authorizationCancelled
        #expect(error.errorDescription == "The user cancelled the Sign In With Yahoo authorization flow.")
    }
}
