//
//  CDYahooMockURLProtocol.swift
//  CDYahooKitTesting
//

import Foundation

/// A `URLProtocol` that intercepts every request and returns a pre-configured response, for
/// testing `CDYahooURLSession` and its callers without making a real network call.
///
/// Two ways to attach a stub: `stubbing(_:with:)` attaches to one specific `URLRequest` instance;
/// `register(stub:for:)` associates a stub with a `URL` in a lock-protected dictionary, for code
/// under test that builds its own `URLRequest` internally (e.g. `CDYahooFantasyAPIClient`'s
/// fetch methods, built via `CDYahooRouter`). Give each registration a distinct `URL` so
/// concurrently-running tests never collide on the same entry.
public final class CDYahooMockURLProtocol: URLProtocol, @unchecked Sendable {

    public struct Stub: Sendable {
        public let statusCode: Int
        public let data: Data
        public let headers: [String: String]
        public let error: (any Error & Sendable)?
        public let delay: TimeInterval

        public init(statusCode: Int = 200, data: Data = Data(), headers: [String: String] = [:],
                    error: (any Error & Sendable)? = nil, delay: TimeInterval = 0) {
            self.statusCode = statusCode
            self.data = data
            self.headers = headers
            self.error = error
            self.delay = delay
        }
    }

    private static let stubPropertyKey = "CDYahooMockURLProtocolStub"
    private static let urlKeyedStubsLock = NSLock()
    private nonisolated(unsafe) static var urlKeyedStubQueues: [URL: [Stub]] = [:]
    private nonisolated(unsafe) static var urlKeyedRequestCounts: [URL: Int] = [:]

    public static func stubbing(_ request: URLRequest, with stub: Stub) -> URLRequest {
        guard let mutableRequest = (request as NSURLRequest).mutableCopy() as? NSMutableURLRequest else {
            return request
        }
        URLProtocol.setProperty(stub, forKey: stubPropertyKey, in: mutableRequest)
        return mutableRequest as URLRequest
    }

    public static func register(stub: Stub, for url: URL) {
        register(stubs: [stub], for: url)
    }

    public static func register(stubs: [Stub], for url: URL) {
        urlKeyedStubsLock.lock()
        defer { urlKeyedStubsLock.unlock() }
        urlKeyedStubQueues[url] = stubs
        urlKeyedRequestCounts[url] = 0
    }

    public static func requestCount(for url: URL) -> Int {
        urlKeyedStubsLock.lock()
        defer { urlKeyedStubsLock.unlock() }
        return urlKeyedRequestCounts[url] ?? 0
    }

    private static func urlKeyedStub(for url: URL?) -> Stub? {
        guard let url else { return nil }
        urlKeyedStubsLock.lock()
        defer { urlKeyedStubsLock.unlock() }
        guard var queue = urlKeyedStubQueues[url], let stub = queue.first else { return nil }
        if queue.count > 1 {
            queue.removeFirst()
            urlKeyedStubQueues[url] = queue
        }
        urlKeyedRequestCounts[url, default: 0] += 1
        return stub
    }

    public static func makeSession() -> URLSession {
        let configuration = URLSessionConfiguration.ephemeral
        configuration.protocolClasses = [CDYahooMockURLProtocol.self]
        return URLSession(configuration: configuration)
    }

    override public static func canInit(with request: URLRequest) -> Bool { true }
    override public static func canonicalRequest(for request: URLRequest) -> URLRequest { request }

    override public func startLoading() {
        guard let stub = (URLProtocol.property(forKey: Self.stubPropertyKey, in: request) as? Stub)
            ?? Self.urlKeyedStub(for: request.url)
        else {
            client?.urlProtocol(self, didFailWithError: URLError(.unknown))
            return
        }
        guard stub.delay > 0 else {
            respond(with: stub)
            return
        }
        DispatchQueue.global().asyncAfter(deadline: .now() + stub.delay) { [weak self] in
            self?.respond(with: stub)
        }
    }

    override public func stopLoading() {}

    private func respond(with stub: Stub) {
        if let error = stub.error {
            client?.urlProtocol(self, didFailWithError: error)
            return
        }
        let response = HTTPURLResponse(
            url: request.url ?? URL(string: "https://fantasysports.yahooapis.com/fantasy/v2/")!,
            statusCode: stub.statusCode,
            httpVersion: "HTTP/1.1",
            headerFields: stub.headers
        )!
        client?.urlProtocol(self, didReceive: response, cacheStoragePolicy: .notAllowed)
        client?.urlProtocol(self, didLoad: stub.data)
        client?.urlProtocolDidFinishLoading(self)
    }
}
