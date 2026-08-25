//
//  CDYahooXMLNode.swift
//  CDYahooKit
//

import Foundation

/// An in-memory tree node built from a Yahoo Fantasy Sports API XML response.
///
/// Every response model implements `init(node:)` against this tree instead of `Codable`'s
/// `init(from:)`, since Fantasy Sports API responses are XML, not JSON — see the "XML Parsing"
/// section of the design spec for why a shared tree beats a bespoke `XMLParser` delegate per
/// resource type.
struct CDYahooXMLNode {
    let name: String
    var attributes: [String: String]
    var children: [CDYahooXMLNode]
    var text: String

    init(name: String, attributes: [String: String] = [:], children: [CDYahooXMLNode] = [], text: String = "") {
        self.name = name
        self.attributes = attributes
        self.children = children
        self.text = text
    }

    /// The first direct child element named `name`, if any.
    func child(_ name: String) -> CDYahooXMLNode? {
        children.first { $0.name == name }
    }

    /// Every direct child element named `name`, in document order.
    func children(_ name: String) -> [CDYahooXMLNode] {
        children.filter { $0.name == name }
    }

    /// The trimmed text content of the first direct child named `name`, or `nil` if the child
    /// is missing, self-closing, or empty — Yahoo represents "no value" both ways depending on
    /// the field, so callers shouldn't have to distinguish them.
    func text(_ name: String) -> String? {
        guard let value = child(name)?.text, !value.isEmpty else { return nil }
        return value
    }

    /// `text(name)` parsed as an `Int`, or `nil` if missing or non-numeric.
    func int(_ name: String) -> Int? {
        text(name).flatMap(Int.init)
    }
}

/// Thrown by a response model's `init(node:)` when a required XML field is missing.
struct CDYahooXMLDecodingError: Error, LocalizedError {
    let missingField: String

    static func missingField(_ field: String) -> CDYahooXMLDecodingError {
        CDYahooXMLDecodingError(missingField: field)
    }

    var errorDescription: String? {
        "Missing required XML field: \(missingField)"
    }
}
