//
//  CDYahooEventMonitor.swift
//  CDYahooKit
//

import Foundation

/// Observes request/response lifecycle events on every request `CDYahooURLSession` sends.
public protocol CDYahooEventMonitor: Sendable {
    func willSend(_ request: URLRequest)
    func didReceive(_ response: URLResponse?, data: Data?, error: (any Error)?)
}
