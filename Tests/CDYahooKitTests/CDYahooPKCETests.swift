//
//  CDYahooPKCETests.swift
//  CDYahooKitTests
//

import Testing
@testable import CDYahooKit

@Suite("CDYahooPKCE")
struct CDYahooPKCETests {

    @Test("makeCodeVerifier produces a 43-character base64url string with no padding")
    func codeVerifierIsWellFormed() {
        let verifier = CDYahooPKCE.makeCodeVerifier()
        #expect(verifier.count == 43)
        #expect(verifier.allSatisfy { $0.isLetter || $0.isNumber || $0 == "-" || $0 == "_" })
    }

    @Test("makeCodeVerifier produces a different value on each call")
    func codeVerifierIsRandom() {
        #expect(CDYahooPKCE.makeCodeVerifier() != CDYahooPKCE.makeCodeVerifier())
    }

    @Test("codeChallenge is deterministic for the same verifier")
    func codeChallengeIsDeterministic() {
        let verifier = "fixed-test-verifier-value"
        #expect(CDYahooPKCE.codeChallenge(for: verifier) == CDYahooPKCE.codeChallenge(for: verifier))
    }

    @Test("codeChallenge is a 43-character base64url string with no padding")
    func codeChallengeIsWellFormed() {
        let challenge = CDYahooPKCE.codeChallenge(for: "fixed-test-verifier-value")
        #expect(challenge.count == 43)
        #expect(challenge.allSatisfy { $0.isLetter || $0.isNumber || $0 == "-" || $0 == "_" })
    }

    @Test("codeChallenge matches the RFC 7636 Appendix B reference vector")
    func codeChallengeMatchesRFC7636Vector() {
        let verifier = "dBjftJeZ4CVP-mB92K27uhbUJU1p1r_wW1gFWFOEjXk"
        let expectedChallenge = "E9Melhoa2OwvFrEMTJguCHaoeK1t8URWbuGJSstw-cM"
        #expect(CDYahooPKCE.codeChallenge(for: verifier) == expectedChallenge)
    }
}
