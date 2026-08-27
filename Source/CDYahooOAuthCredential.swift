//
//  CDYahooOAuthCredential.swift
//  CDYahooKit
//

import Foundation

/// The JSON response from Yahoo's OAuth 2.0 token endpoint (`/oauth2/get_token`) — unlike the
/// Fantasy Sports data API, the OAuth token endpoint returns JSON, not XML.
struct CDYahooOAuthCredential: Codable, Sendable {
    let accessToken: String
    let refreshToken: String?
    let expiresIn: Int
    let tokenType: String
    let xoauthYahooGuid: String?

    enum CodingKeys: String, CodingKey {
        case accessToken = "access_token"
        case refreshToken = "refresh_token"
        case expiresIn = "expires_in"
        case tokenType = "token_type"
        case xoauthYahooGuid = "xoauth_yahoo_guid"
    }
}
