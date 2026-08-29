//
//  CDYahooLeaguePlayersQueryTests.swift
//  CDYahooKitTests
//

import Testing
@testable import CDYahooKit

@Suite("CDYahooLeaguePlayersQuery")
struct CDYahooLeaguePlayersQueryTests {

    @Test("an empty query emits no matrix parameters")
    func emptyQueryEmitsNothing() {
        #expect(CDYahooLeaguePlayersQuery().pathModifier == "")
    }

    @Test("start and count emit ;start= / ;count=")
    func paginationParameters() {
        #expect(CDYahooLeaguePlayersQuery(start: 25).pathModifier == ";start=25")
        #expect(CDYahooLeaguePlayersQuery(count: 10).pathModifier == ";count=10")
        #expect(CDYahooLeaguePlayersQuery(start: 25, count: 10).pathModifier == ";start=25;count=10")
    }

    @Test("subresources emit a single comma-joined ;out= in a fixed order")
    func subresourcesJoinIntoOneOut() {
        #expect(CDYahooLeaguePlayersQuery(subresources: .percentOwned).pathModifier == ";out=percent_owned")
        #expect(
            CDYahooLeaguePlayersQuery(subresources: [.ownership, .stats, .percentOwned]).pathModifier
                == ";out=stats,percent_owned,ownership"
        )
    }

    @Test("status maps to Yahoo's short filter codes")
    func statusFilterCodes() {
        #expect(CDYahooLeaguePlayersQuery(status: .available).pathModifier == ";status=A")
        #expect(CDYahooLeaguePlayersQuery(status: .freeAgents).pathModifier == ";status=FA")
        #expect(CDYahooLeaguePlayersQuery(status: .waivers).pathModifier == ";status=W")
        #expect(CDYahooLeaguePlayersQuery(status: .taken).pathModifier == ";status=T")
        #expect(CDYahooLeaguePlayersQuery(status: .keepers).pathModifier == ";status=K")
    }

    @Test("sort maps keywords to codes and a stat id to its raw value")
    func sortCodes() {
        #expect(CDYahooLeaguePlayersQuery(sort: .name).pathModifier == ";sort=NAME")
        #expect(CDYahooLeaguePlayersQuery(sort: .overallRank).pathModifier == ";sort=OR")
        #expect(CDYahooLeaguePlayersQuery(sort: .actualRank).pathModifier == ";sort=AR")
        #expect(CDYahooLeaguePlayersQuery(sort: .points).pathModifier == ";sort=PTS")
        #expect(CDYahooLeaguePlayersQuery(sort: .stat(60)).pathModifier == ";sort=60")
    }

    @Test("position is emitted verbatim")
    func positionParameter() {
        #expect(CDYahooLeaguePlayersQuery(position: "QB").pathModifier == ";position=QB")
    }

    @Test("search values are percent-encoded so spaces can't reshape the path")
    func searchIsPercentEncoded() {
        #expect(CDYahooLeaguePlayersQuery(search: "Josh Allen").pathModifier == ";search=Josh%20Allen")
    }

    @Test("all modifiers combine in a stable order")
    func combinedModifierOrder() {
        let query = CDYahooLeaguePlayersQuery(
            subresources: [.stats, .percentOwned],
            position: "WR",
            status: .freeAgents,
            search: "Lee",
            sort: .points,
            start: 25,
            count: 5
        )
        #expect(
            query.pathModifier
                == ";out=stats,percent_owned;position=WR;status=FA;search=Lee;sort=PTS;start=25;count=5"
        )
    }
}
