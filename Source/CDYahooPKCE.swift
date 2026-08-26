//
//  CDYahooPKCE.swift
//  CDYahooKit
//

import CryptoKit
import Foundation
import Security

/// PKCE (RFC 7636) code verifier/challenge generation for the Sign In With Yahoo OAuth 2.0
/// authorization code flow.
public enum CDYahooPKCE {

    /// A cryptographically random 32-byte verifier, base64url-encoded (43 characters, no
    /// padding) — within RFC 7636's required 43-128 character range.
    public static func makeCodeVerifier() -> String {
        var bytes = [UInt8](repeating: 0, count: 32)
        _ = SecRandomCopyBytes(kSecRandomDefault, bytes.count, &bytes)
        return base64URLEncode(Data(bytes))
    }

    /// The S256 challenge for `verifier`: base64url(SHA256(verifier)).
    public static func codeChallenge(for verifier: String) -> String {
        let digest = SHA256.hash(data: Data(verifier.utf8))
        return base64URLEncode(Data(digest))
    }

    private static func base64URLEncode(_ data: Data) -> String {
        data.base64EncodedString()
            .replacingOccurrences(of: "+", with: "-")
            .replacingOccurrences(of: "/", with: "_")
            .replacingOccurrences(of: "=", with: "")
    }
}
