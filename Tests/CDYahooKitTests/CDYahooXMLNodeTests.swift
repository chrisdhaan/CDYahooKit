//
//  CDYahooXMLNodeTests.swift
//  CDYahooKitTests
//

import Testing
@testable import CDYahooKit

@Suite("CDYahooXMLNode")
struct CDYahooXMLNodeTests {

    @Test("child(_:) finds the first matching direct child")
    func childFindsFirstMatch() {
        let node = CDYahooXMLNode(name: "league", children: [
            CDYahooXMLNode(name: "name", text: "My League"),
            CDYahooXMLNode(name: "name", text: "Ignored Duplicate")
        ])
        #expect(node.child("name")?.text == "My League")
    }

    @Test("children(_:) returns every matching direct child, in order")
    func childrenReturnsAllMatches() {
        let node = CDYahooXMLNode(name: "teams", children: [
            CDYahooXMLNode(name: "team", text: "1"),
            CDYahooXMLNode(name: "team", text: "2"),
            CDYahooXMLNode(name: "other", text: "3")
        ])
        #expect(node.children("team").map(\.text) == ["1", "2"])
    }

    @Test("text(_:) returns nil for an empty or self-closing element")
    func textReturnsNilForEmptyElement() {
        let node = CDYahooXMLNode(name: "player", children: [
            CDYahooXMLNode(name: "status", text: "")
        ])
        #expect(node.text("status") == nil)
    }

    @Test("int(_:) parses a numeric child's text")
    func intParsesNumericText() {
        let node = CDYahooXMLNode(name: "league", children: [
            CDYahooXMLNode(name: "num_teams", text: "10")
        ])
        #expect(node.int("num_teams") == 10)
    }

    @Test("int(_:) returns nil when the child is missing")
    func intReturnsNilWhenMissing() {
        let node = CDYahooXMLNode(name: "league", children: [])
        #expect(node.int("num_teams") == nil)
    }

    @Test("bool(_:) reads Yahoo's 1/0 flag encoding and rejects anything else")
    func boolReadsYahooFlagEncoding() {
        let node = CDYahooXMLNode(name: "settings", children: [
            CDYahooXMLNode(name: "uses_playoff", text: "1"),
            CDYahooXMLNode(name: "uses_faab", text: "0"),
            CDYahooXMLNode(name: "waiver_rule", text: "gametime")
        ])
        #expect(node.bool("uses_playoff") == true)
        #expect(node.bool("uses_faab") == false)
        #expect(node.bool("waiver_rule") == nil)
        #expect(node.bool("missing") == nil)
    }
}
