//
//  XMLResponseRecorder.swift
//  iOS Example
//

import CDYahooKit
import Foundation

/// A `CDYahooEventMonitor` that keeps the raw body of the most recent Fantasy Sports API
/// response so the Example can display the exact XML Yahoo returned.
///
/// Doubles as a live demonstration of CDYahooKit's public event-monitor hook: the recorder is
/// handed to `CDYahooFantasyAPIClient(eventMonitors:)` at construction and observes every
/// request the client sends.
final class XMLResponseRecorder: CDYahooEventMonitor, @unchecked Sendable {

    private let lock = NSLock()
    private var storedBody: Data?

    /// The unparsed body of the most recent response, or `nil` if no request has completed yet.
    var lastResponseBody: Data? {
        lock.lock()
        defer { lock.unlock() }
        return storedBody
    }

    func willSend(_ request: URLRequest) {}

    func didReceive(_ response: URLResponse?, data: Data?, error: (any Error)?) {
        lock.lock()
        defer { lock.unlock() }
        storedBody = data
    }
}
