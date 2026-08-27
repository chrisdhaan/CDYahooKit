//
//  CDYahooXMLTreeBuilderTests.swift
//  CDYahooKitTests
//

import Foundation
import Testing
@testable import CDYahooKit

@Suite("CDYahooXMLTreeBuilder")
struct CDYahooXMLTreeBuilderTests {

    @Test("parses nested elements, repeated siblings, attributes, and text content")
    func parsesNestedDocument() throws {
        let xml = """
        <?xml version="1.0" encoding="UTF-8"?>
        <fantasy_content>
            <league>
                <league_key>449.l.12345</league_key>
                <standings>
                    <teams count="2">
                        <team><team_id>1</team_id></team>
                        <team><team_id>2</team_id></team>
                    </teams>
                </standings>
            </league>
        </fantasy_content>
        """
        let root = try CDYahooXMLTreeBuilder.parse(Data(xml.utf8))

        #expect(root.name == "fantasy_content")
        let league = try #require(root.child("league"))
        #expect(league.text("league_key") == "449.l.12345")

        let teamsNode = try #require(league.child("standings")?.child("teams"))
        #expect(teamsNode.attributes["count"] == "2")
        #expect(teamsNode.children("team").map { $0.text("team_id") } == ["1", "2"])
    }

    @Test("self-closing elements produce an empty-text node, not a crash")
    func handlesSelfClosingElements() throws {
        let root = try CDYahooXMLTreeBuilder.parse(Data("<player><status/></player>".utf8))
        #expect(root.text("status") == nil)
    }

    @Test("malformed XML throws xmlParsingFailed")
    func malformedXMLThrows() throws {
        let thrown = try #require(throws: CDYahooKitError.self) {
            _ = try CDYahooXMLTreeBuilder.parse(Data("<not><closed>".utf8))
        }
        guard case .xmlParsingFailed = thrown else {
            Issue.record("Expected .xmlParsingFailed, got \(thrown)")
            return
        }
    }
}
