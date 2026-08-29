//
//  CDYahooFantasyAPIClientTests.swift
//  CDYahooKitTests
//

import CDYahooKitTesting
import Foundation
import Testing
@testable import CDYahooKit

/// Nested inside CDYahooOAuthClientTests (not just independently .serialized) because both
/// suites share the real, process-global Keychain via fixed key names in CDYahooKeychain — two
/// independently-.serialized top-level suites can still run concurrently WITH each other and
/// race on that shared state (one suite's unauthorize() landing between the other's own
/// authorize() and its next assertion). Swift Testing's .serialized trait cascades to nested
/// sub-suites, so nesting here closes that gap; two independent top-level suites would not.
extension CDYahooOAuthClientTests {

    @MainActor
    @Suite("CDYahooFantasyAPIClient", .serialized)
    struct CDYahooFantasyAPIClientTests {

        private func makeClient() async -> CDYahooFantasyAPIClient {
            let configuration = URLSessionConfiguration.ephemeral
            configuration.protocolClasses = [CDYahooMockURLProtocol.self]
            let client = CDYahooFantasyAPIClient(clientId: "client-id", clientSecret: "client-secret",
                                                 redirectUrl: "myapp://callback",
                                                 urlSession: URLSession(configuration: configuration))
            await client.oAuthClient.unauthorize()
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
            let client = await makeClient()
            stubTokenEndpoint()
            try await client.oAuthClient.authorize(withCode: "code", codeVerifier: "verifier")

            try CDYahooMockURLProtocol.register(
                stub: .init(statusCode: 200, data: fixtureData("UserGames")),
                for: #require(URL(string: "https://fantasysports.yahooapis.com/fantasy/v2/users;use_login=1/games;game_codes=nfl/leagues"))
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
            let client = await makeClient()
            stubTokenEndpoint()
            try await client.oAuthClient.authorize(withCode: "code", codeVerifier: "verifier")

            try CDYahooMockURLProtocol.register(
                stub: .init(statusCode: 200, data: fixtureData("League")),
                for: #require(URL(string: "https://fantasysports.yahooapis.com/fantasy/v2/league/449.l.12345"))
            )

            let response = try await client.fetchLeague(leagueKey: "449.l.12345")
            #expect(response.league.name == "My Fantasy League")
            #expect(response.league.numTeams == 10)
            #expect(response.league.scoringType == "head")
            #expect(response.league.currentWeek == 8)
        }

        @Test("fetchLeagueStandings decodes ranked teams with outcome totals")
        func fetchLeagueStandingsDecodesFixture() async throws {
            let client = await makeClient()
            stubTokenEndpoint()
            try await client.oAuthClient.authorize(withCode: "code", codeVerifier: "verifier")

            try CDYahooMockURLProtocol.register(
                stub: .init(statusCode: 200, data: fixtureData("LeagueStandings")),
                for: #require(URL(string: "https://fantasysports.yahooapis.com/fantasy/v2/league/449.l.12345/standings"))
            )

            let response = try await client.fetchLeagueStandings(leagueKey: "449.l.12345")
            #expect(response.teams.count == 2)

            let first = try #require(response.teams.first)
            #expect(first.name == "Team Alpha")
            #expect(first.rank == 1)
            #expect(first.outcomeTotals?.wins == 8)
            #expect(first.pointsFor == 1234.5)
        }

        @Test("fetchTeamRoster decodes players with their selected position")
        func fetchTeamRosterDecodesFixture() async throws {
            let client = await makeClient()
            stubTokenEndpoint()
            try await client.oAuthClient.authorize(withCode: "code", codeVerifier: "verifier")

            try CDYahooMockURLProtocol.register(
                stub: .init(statusCode: 200, data: fixtureData("TeamRoster")),
                for: #require(URL(string: "https://fantasysports.yahooapis.com/fantasy/v2/team/449.l.12345.t.1/roster;week=8"))
            )

            let response = try await client.fetchTeamRoster(teamKey: "449.l.12345.t.1", week: 8)
            #expect(response.players.count == 2)

            let quarterback = try #require(response.players.first)
            #expect(quarterback.fullName == "Jane Doe")
            #expect(quarterback.selectedPosition == "QB")

            let benched = response.players[1]
            #expect(benched.selectedPosition == "BN")
        }

        @Test("fetchLeaguePlayers decodes the league's player pool")
        func fetchLeaguePlayersDecodesFixture() async throws {
            let client = await makeClient()
            stubTokenEndpoint()
            try await client.oAuthClient.authorize(withCode: "code", codeVerifier: "verifier")

            try CDYahooMockURLProtocol.register(
                stub: .init(statusCode: 200, data: fixtureData("LeaguePlayers")),
                for: #require(URL(string: "https://fantasysports.yahooapis.com/fantasy/v2/league/449.l.12345/players"))
            )

            let response = try await client.fetchLeaguePlayers(leagueKey: "449.l.12345", start: nil)
            #expect(response.players.count == 2)
            #expect(response.players.first?.status == "ACT")
            #expect(response.players.last?.status == nil)
        }

        @Test("fetchLeagueScoreboard decodes matchups with each team's points")
        func fetchLeagueScoreboardDecodesFixture() async throws {
            let client = await makeClient()
            stubTokenEndpoint()
            try await client.oAuthClient.authorize(withCode: "code", codeVerifier: "verifier")

            try CDYahooMockURLProtocol.register(
                stub: .init(statusCode: 200, data: fixtureData("LeagueScoreboard")),
                for: #require(URL(string: "https://fantasysports.yahooapis.com/fantasy/v2/league/449.l.12345/scoreboard;week=8"))
            )

            let response = try await client.fetchLeagueScoreboard(leagueKey: "449.l.12345", week: 8)
            #expect(response.matchups.count == 1)

            let matchup = try #require(response.matchups.first)
            #expect(matchup.week == 8)
            #expect(matchup.teams.count == 2)
            #expect(matchup.teams.first?.totalPoints == 112.5)
        }

        @Test("fetchLeagueTransactions decodes transactions and the players they moved")
        func fetchLeagueTransactionsDecodesFixture() async throws {
            let client = await makeClient()
            stubTokenEndpoint()
            try await client.oAuthClient.authorize(withCode: "code", codeVerifier: "verifier")

            try CDYahooMockURLProtocol.register(
                stub: .init(statusCode: 200, data: fixtureData("LeagueTransactions")),
                for: #require(URL(string: "https://fantasysports.yahooapis.com/fantasy/v2/league/449.l.12345/transactions"))
            )

            let response = try await client.fetchLeagueTransactions(leagueKey: "449.l.12345")
            #expect(response.transactions.count == 1)

            let transaction = try #require(response.transactions.first)
            #expect(transaction.type == "add/drop")
            #expect(transaction.players.first?.fullName == "Sam Lee")
            #expect(transaction.players.first?.transactionType == "add")
        }

        @Test("fetchLeagueSettings decodes scoring, roster, stat, waiver/trade, and playoff config")
        func fetchLeagueSettingsDecodesFixture() async throws {
            let client = await makeClient()
            stubTokenEndpoint()
            try await client.oAuthClient.authorize(withCode: "code", codeVerifier: "verifier")

            try CDYahooMockURLProtocol.register(
                stub: .init(statusCode: 200, data: fixtureData("LeagueSettings")),
                for: #require(URL(string: "https://fantasysports.yahooapis.com/fantasy/v2/league/449.l.12345/settings"))
            )

            let response = try await client.fetchLeagueSettings(leagueKey: "449.l.12345")
            #expect(response.leagueKey == "449.l.12345")

            let settings = response.settings
            #expect(settings.scoringType == "head")
            #expect(settings.usesPlayoff == true)
            #expect(settings.playoffStartWeek == 15)
            #expect(settings.numPlayoffTeams == 6)
            #expect(settings.numPlayoffConsolationTeams == 4)
            #expect(settings.usesPlayoffReseeding == false)
            #expect(settings.waiverType == "R")
            #expect(settings.waiverRule == "gametime")
            #expect(settings.usesFaab == false)
            #expect(settings.waiverTime == 2)
            #expect(settings.tradeEndDate == "2025-11-14")
            #expect(settings.tradeRatifyType == "commish")
            #expect(settings.tradeRejectTime == 2)

            #expect(settings.rosterPositions.count == 2)
            let quarterback = try #require(settings.rosterPositions.first)
            #expect(quarterback.position == "QB")
            #expect(quarterback.positionType == "O")
            #expect(quarterback.count == 1)
            #expect(settings.rosterPositions.last?.position == "BN")
            #expect(settings.rosterPositions.last?.positionType == nil)

            #expect(settings.statCategories.count == 2)
            let passingYards = try #require(settings.statCategories.first)
            #expect(passingYards.statId == 4)
            #expect(passingYards.name == "Passing Yards")
            #expect(passingYards.displayName == "Pass Yds")
            #expect(passingYards.enabled == true)
            #expect(passingYards.sortOrder == 1)
            #expect(passingYards.positionType == "O")

            #expect(settings.statModifiers.count == 2)
            let passingYardsModifier = try #require(settings.statModifiers.first)
            #expect(passingYardsModifier.statId == 4)
            #expect(passingYardsModifier.value == 0.04)
        }
    }

}
