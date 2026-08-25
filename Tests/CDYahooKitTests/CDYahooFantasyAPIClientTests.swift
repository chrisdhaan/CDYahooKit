//
//  CDYahooFantasyAPIClientTests.swift
//  CDYahooKitTests
//

import Foundation
import Testing
@testable import CDYahooKit
import CDYahooKitTesting

// .serialized for the same reason as CDYahooOAuthClientTests (Task 11): every test here also
// stubs the fixed OAuth token endpoint URL via stubTokenEndpoint() before exercising a Fantasy
// API call.
@MainActor
@Suite("CDYahooFantasyAPIClient", .serialized)
struct CDYahooFantasyAPIClientTests {

    private func makeClient() -> CDYahooFantasyAPIClient {
        let configuration = URLSessionConfiguration.ephemeral
        configuration.protocolClasses = [CDYahooMockURLProtocol.self]
        let client = CDYahooFantasyAPIClient(clientId: "client-id", clientSecret: "client-secret",
                                              redirectUrl: "myapp://callback",
                                              urlSession: URLSession(configuration: configuration))
        client.oAuthClient.unauthorize()
        return client
    }

    private func fixtureData(_ name: String) throws -> Data {
        let url = try #require(Bundle.module.url(forResource: name, withExtension: "xml"))
        return try Data(contentsOf: url)
    }

    private func stubTokenEndpoint() {
        CDYahooMockURLProtocol.register(
            stub: .init(statusCode: 200, data: Data("""
            {"access_token":"access-abc","refresh_token":"refresh-abc","expires_in":3600,"token_type":"bearer"}
            """.utf8)),
            for: URL(string: "https://api.login.yahoo.com/oauth2/get_token")!
        )
    }

    @Test("fetchUserGames decodes the authenticated user's games and leagues")
    func fetchUserGamesDecodesFixture() async throws {
        let client = makeClient()
        stubTokenEndpoint()
        try await client.oAuthClient.authorize(withCode: "code", codeVerifier: "verifier")

        CDYahooMockURLProtocol.register(
            stub: .init(statusCode: 200, data: try fixtureData("UserGames")),
            for: URL(string: "https://fantasysports.yahooapis.com/fantasy/v2/users;use_login=1/games;game_codes=nfl/leagues")!
        )

        let response = try await client.fetchUserGames()
        #expect(response.games.count == 1)

        let game = try #require(response.games.first)
        #expect(game.gameKey == "449")
        #expect(game.code == "nfl")
        #expect(game.season == "2025")

        let league = try #require(game.leagues.first)
        #expect(league.leagueKey == "449.l.12345")
        #expect(league.name == "My Fantasy League")
        #expect(league.numTeams == 10)
    }

    @Test("fetchLeague decodes league metadata")
    func fetchLeagueDecodesFixture() async throws {
        let client = makeClient()
        stubTokenEndpoint()
        try await client.oAuthClient.authorize(withCode: "code", codeVerifier: "verifier")

        CDYahooMockURLProtocol.register(
            stub: .init(statusCode: 200, data: try fixtureData("League")),
            for: URL(string: "https://fantasysports.yahooapis.com/fantasy/v2/league/449.l.12345")!
        )

        let response = try await client.fetchLeague(leagueKey: "449.l.12345")
        #expect(response.league.name == "My Fantasy League")
        #expect(response.league.numTeams == 10)
        #expect(response.league.scoringType == "head")
        #expect(response.league.currentWeek == 8)
    }

    @Test("fetchLeagueStandings decodes ranked teams with outcome totals")
    func fetchLeagueStandingsDecodesFixture() async throws {
        let client = makeClient()
        stubTokenEndpoint()
        try await client.oAuthClient.authorize(withCode: "code", codeVerifier: "verifier")

        CDYahooMockURLProtocol.register(
            stub: .init(statusCode: 200, data: try fixtureData("LeagueStandings")),
            for: URL(string: "https://fantasysports.yahooapis.com/fantasy/v2/league/449.l.12345/standings")!
        )

        let response = try await client.fetchLeagueStandings(leagueKey: "449.l.12345")
        #expect(response.teams.count == 2)

        let first = try #require(response.teams.first)
        #expect(first.name == "Team Alpha")
        #expect(first.rank == 1)
        #expect(first.outcomeTotals?.wins == 8)
        #expect(first.pointsFor == 1234.5)
    }
}
