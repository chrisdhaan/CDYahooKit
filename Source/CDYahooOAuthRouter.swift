//
//  CDYahooOAuthRouter.swift
//  CDYahooKit
//

import Foundation

/// Builds requests to Yahoo's OAuth 2.0 token endpoint.
enum CDYahooOAuthRouter {
    case authorize(code: String, redirectUrl: String, codeVerifier: String)
    case refresh(refreshToken: String, redirectUrl: String)

    func asURLRequest(clientId: String, clientSecret: String) throws -> URLRequest {
        guard let url = URL(string: CDYahooConstants.oauthTokenURL) else {
            throw CDYahooKitError.invalidRequest(underlying: URLError(.badURL))
        }
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/x-www-form-urlencoded", forHTTPHeaderField: "Content-Type")

        guard let credentialsData = "\(clientId):\(clientSecret)".data(using: .utf8) else {
            throw CDYahooKitError.invalidCredentials("clientId/clientSecret could not be encoded.")
        }
        request.setValue("Basic \(credentialsData.base64EncodedString())", forHTTPHeaderField: "Authorization")

        let params: [String: String]
        switch self {
        case let .authorize(code, redirectUrl, codeVerifier):
            params = ["grant_type": "authorization_code",
                      "redirect_uri": redirectUrl,
                      "code": code,
                      "code_verifier": codeVerifier]
        case let .refresh(refreshToken, redirectUrl):
            params = ["grant_type": "refresh_token",
                      "redirect_uri": redirectUrl,
                      "refresh_token": refreshToken]
        }

        var allowedCharacters = CharacterSet.urlQueryAllowed
        allowedCharacters.remove(charactersIn: "+&=")
        let body = params
            .map { key, value in "\(key)=\(value.addingPercentEncoding(withAllowedCharacters: allowedCharacters) ?? value)" }
            .joined(separator: "&")
        request.httpBody = Data(body.utf8)
        return request
    }
}
