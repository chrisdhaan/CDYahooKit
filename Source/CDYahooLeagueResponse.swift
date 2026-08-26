//
//  CDYahooLeagueResponse.swift
//  CDYahooKit
//

/// The response from `league/{league_key}`.
public struct CDYahooLeagueResponse: CDYahooXMLDecodable, Sendable {
    public let league: CDYahooLeague

    public init(league: CDYahooLeague) {
        self.league = league
    }

    init(node: CDYahooXMLNode) throws {
        guard let leagueNode = node.child("league") else {
            throw CDYahooXMLDecodingError.missingField("league")
        }
        self.league = try CDYahooLeague(node: leagueNode)
    }
}
