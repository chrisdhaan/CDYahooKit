//
//  CDYahooXMLTreeBuilder.swift
//  CDYahooKit
//

import Foundation

/// Parses a Yahoo Fantasy Sports API XML response into a `CDYahooXMLNode` tree in a single pass.
/// This is the only place `XMLParser`'s delegate callbacks are handled directly — every response
/// model then reads from the resulting tree via `init(node:)` instead of implementing its own
/// SAX delegate.
final class CDYahooXMLTreeBuilder: NSObject, XMLParserDelegate {

    private var stack: [CDYahooXMLNode] = []
    private var root: CDYahooXMLNode?
    private var parseError: (any Error)?

    static func parse(_ data: Data) throws -> CDYahooXMLNode {
        let builder = CDYahooXMLTreeBuilder()
        let parser = XMLParser(data: data)
        parser.delegate = builder
        guard parser.parse() else {
            throw CDYahooKitError.xmlParsingFailed(underlying: builder.parseError ?? parser.parserError ?? URLError(.cannotParseResponse))
        }
        guard let root = builder.root else {
            throw CDYahooKitError.xmlParsingFailed(underlying: URLError(.cannotParseResponse))
        }
        return root
    }

    func parser(_ parser: XMLParser, didStartElement elementName: String, namespaceURI: String?,
                qualifiedName qName: String?, attributes attributeDict: [String: String] = [:]) {
        stack.append(CDYahooXMLNode(name: elementName, attributes: attributeDict))
    }

    func parser(_ parser: XMLParser, foundCharacters string: String) {
        guard !stack.isEmpty else { return }
        stack[stack.count - 1].text += string
    }

    func parser(_ parser: XMLParser, didEndElement elementName: String, namespaceURI: String?, qualifiedName qName: String?) {
        guard var finished = stack.popLast() else { return }
        finished.text = finished.text.trimmingCharacters(in: .whitespacesAndNewlines)
        if stack.isEmpty {
            root = finished
        } else {
            stack[stack.count - 1].children.append(finished)
        }
    }

    func parser(_ parser: XMLParser, parseErrorOccurred parseError: any Error) {
        self.parseError = parseError
    }
}
