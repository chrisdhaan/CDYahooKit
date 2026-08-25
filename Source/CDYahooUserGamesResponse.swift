//
//  CDYahooUserGamesResponse.swift
//  CDYahooKit
//

/// The response from `users;use_login=1/games;game_codes={code}/leagues` — every fantasy game
/// and league the authenticated user has a team in for the requested game code.
public struct CDYahooUserGamesResponse: CDYahooXMLDecodable, Sendable {
    public let games: [CDYahooGame]

    init(node: CDYahooXMLNode) throws {
        guard let user = node.child("users")?.child("user") else {
            throw CDYahooXMLDecodingError.missingField("users/user")
        }
        self.games = try user.child("games")?.children("game").map(CDYahooGame.init(node:)) ?? []
    }
}
