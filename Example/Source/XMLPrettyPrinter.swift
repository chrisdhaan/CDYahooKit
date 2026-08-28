//
//  XMLPrettyPrinter.swift
//  iOS Example
//

import Foundation

/// Re-indents a raw Fantasy Sports API XML response body for on-screen display.
///
/// The Fantasy Sports API is XML-native, so this Example shows the exact bytes Yahoo returned,
/// re-indented by element depth rather than re-encoded from the decoded models. Parsing is
/// delegated to Foundation's `XMLParser`; a body that isn't well-formed XML is returned
/// verbatim. CDATA sections are rendered as their text content.
enum XMLPrettyPrinter {

    static func string(from data: Data) -> String {
        let formatter = Formatter()
        let parser = XMLParser(data: data)
        parser.delegate = formatter
        parser.shouldProcessNamespaces = false

        guard parser.parse() else {
            return String(data: data, encoding: .utf8) ?? "<undecodable response>"
        }

        let head = String(data: data.prefix(6), encoding: .utf8)
        let declaration = head?.hasPrefix("<?xml") == true ? "<?xml version=\"1.0\" encoding=\"UTF-8\"?>\n" : ""
        return declaration + formatter.output
    }
}

private extension XMLPrettyPrinter {

    /// Rebuilds an indented XML string from `XMLParser` delegate callbacks. A start tag is held
    /// open (no closing `>`) until its content is known, so childless elements collapse to
    /// `<name />` and elements with only text stay on one line.
    final class Formatter: NSObject, XMLParserDelegate {

        private(set) var output = ""
        private var level = 0
        private var openTagUnterminated = false
        private var textBuffer = ""

        func parser(
            _ parser: XMLParser,
            didStartElement elementName: String,
            namespaceURI: String?,
            qualifiedName qName: String?,
            attributes attributeDict: [String: String]
        ) {
            terminateOpenTag()
            if !output.isEmpty { output += "\n" }

            output += indent(level) + "<" + elementName
            for key in attributeDict.keys.sorted() {
                output += " \(key)=\"\(escape(attributeDict[key] ?? ""))\""
            }
            openTagUnterminated = true
            level += 1
        }

        func parser(
            _ parser: XMLParser,
            didEndElement elementName: String,
            namespaceURI: String?,
            qualifiedName qName: String?
        ) {
            level = max(0, level - 1)
            let text = textBuffer.trimmingCharacters(in: .whitespacesAndNewlines)
            textBuffer = ""

            if openTagUnterminated {
                openTagUnterminated = false
                output += text.isEmpty ? " />" : ">\(escape(text))</\(elementName)>"
            } else {
                if !text.isEmpty {
                    output += "\n" + indent(level + 1) + escape(text)
                }
                output += "\n" + indent(level) + "</\(elementName)>"
            }
        }

        func parser(_ parser: XMLParser, foundCharacters string: String) {
            textBuffer += string
        }

        func parser(_ parser: XMLParser, foundCDATA CDATABlock: Data) {
            textBuffer += String(data: CDATABlock, encoding: .utf8) ?? ""
        }

        // MARK: Helpers

        /// Emits the closing `>` for an element that turned out to have child elements.
        private func terminateOpenTag() {
            guard openTagUnterminated else { return }
            output += ">"
            openTagUnterminated = false
        }

        private func indent(_ level: Int) -> String {
            String(repeating: "  ", count: level)
        }

        private func escape(_ value: String) -> String {
            value
                .replacingOccurrences(of: "&", with: "&amp;")
                .replacingOccurrences(of: "<", with: "&lt;")
                .replacingOccurrences(of: ">", with: "&gt;")
                .replacingOccurrences(of: "\"", with: "&quot;")
        }
    }
}
