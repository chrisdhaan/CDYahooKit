//
//  CDYahooKeychain.swift
//  CDYahooKit
//

import Foundation

/// Keychain storage for OAuth 2.0 tokens, scoped to a fixed generic-password service name so
/// entries don't collide with any other framework's Keychain usage in the same app.
enum CDYahooKeychain {

    private static let service = "CDYahooKit"

    @discardableResult
    static func set(_ value: String, forKey key: String) -> Bool {
        guard let data = value.data(using: .utf8) else { return false }
        delete(forKey: key)
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: key,
            kSecValueData as String: data
        ]
        return SecItemAdd(query as CFDictionary, nil) == errSecSuccess
    }

    static func string(forKey key: String) -> String? {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: key,
            kSecReturnData as String: true,
            kSecMatchLimit as String: kSecMatchLimitOne
        ]
        var result: AnyObject?
        guard SecItemCopyMatching(query as CFDictionary, &result) == errSecSuccess,
              let data = result as? Data else { return nil }
        return String(data: data, encoding: .utf8)
    }

    @discardableResult
    static func delete(forKey key: String) -> Bool {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: key
        ]
        let status = SecItemDelete(query as CFDictionary)
        return status == errSecSuccess || status == errSecItemNotFound
    }
}

enum CDYahooDefaults {
    static let accessToken = "CDYahooKit.accessToken"
    static let refreshToken = "CDYahooKit.refreshToken"
    static let tokenExpiry = "CDYahooKit.tokenExpiry"
}
