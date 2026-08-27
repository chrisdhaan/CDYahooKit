//
//  CDYahooRequestAdapter.swift
//  CDYahooKit
//

import Foundation

/// Mutates each outgoing request before `CDYahooURLSession` sends it. Adapters run in the order
/// they were supplied.
public protocol CDYahooRequestAdapter: Sendable {
    func adapt(_ request: URLRequest) -> URLRequest
}
