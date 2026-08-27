//
//  CDYahooXMLDecodable.swift
//  CDYahooKit
//

/// Conformed to by every Fantasy Sports API response/model type. The XML analog of `Decodable`.
protocol CDYahooXMLDecodable {
    init(node: CDYahooXMLNode) throws
}
