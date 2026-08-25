//
//  CDYahooURLSessionTests.swift
//  CDYahooKitTests
//

import Foundation
import Testing
@testable import CDYahooKit

private struct StubResponse: CDYahooXMLDecodable, Equatable {
    let value: String
    init(node: CDYahooXMLNode) throws {
        guard let value = node.text("value") else {
            throw CDYahooXMLDecodingError.missingField("value")
        }
        self.value = value
    }
}

/// Minimal inline stub protocol — superseded by `CDYahooMockURLProtocol` (Task 8) for every
/// later test in this suite.
private final class InlineStubProtocol: URLProtocol, @unchecked Sendable {
    nonisolated(unsafe) static var statusCode = 200
    nonisolated(unsafe) static var body = Data()
    nonisolated(unsafe) static var requestCount = 0

    override class func canInit(with request: URLRequest) -> Bool { true }
    override class func canonicalRequest(for request: URLRequest) -> URLRequest { request }
    override func startLoading() {
        Self.requestCount += 1
        let response = HTTPURLResponse(url: request.url!, statusCode: Self.statusCode, httpVersion: "HTTP/1.1", headerFields: nil)!
        client?.urlProtocol(self, didReceive: response, cacheStoragePolicy: .notAllowed)
        client?.urlProtocol(self, didLoad: Self.body)
        client?.urlProtocolDidFinishLoading(self)
    }
    override func stopLoading() {}
}

// .serialized: every test in this suite shares InlineStubProtocol's process-global static
// state (statusCode, body, requestCount) — a temporary inline stub scoped to this task alone,
// superseded by the thread-safe CDYahooMockURLProtocol in Task 8. Serializing this suite stops
// its own tests from racing each other and reading/resetting each other's stub state mid-flight.
@Suite("CDYahooURLSession", .serialized)
struct CDYahooURLSessionTests {

    private func makeSession(retryConfiguration: CDYahooRetryConfiguration = .disabled,
                              cacheConfiguration: CDYahooCacheConfiguration = .disabled) -> CDYahooURLSession {
        let configuration = URLSessionConfiguration.ephemeral
        configuration.protocolClasses = [InlineStubProtocol.self]
        return CDYahooURLSession(session: URLSession(configuration: configuration),
                                  retryConfiguration: retryConfiguration,
                                  cacheConfiguration: cacheConfiguration)
    }

    @Test("decodes a successful XML response into the requested type")
    func decodesSuccessfulResponse() async throws {
        InlineStubProtocol.statusCode = 200
        InlineStubProtocol.body = Data("<root><value>hello</value></root>".utf8)
        let session = makeSession()

        let result: StubResponse = try await session.perform(URLRequest(url: URL(string: "https://example.com/a")!))
        #expect(result.value == "hello")
    }

    @Test("throws for a non-2xx HTTP status")
    func throwsForNon2xxStatus() async {
        InlineStubProtocol.statusCode = 404
        InlineStubProtocol.body = Data()
        let session = makeSession()

        await #expect(throws: CDYahooKitError.self) {
            let _: StubResponse = try await session.perform(URLRequest(url: URL(string: "https://example.com/b")!))
        }
    }

    @Test("retries the configured number of times before giving up")
    func retriesOnFailure() async {
        InlineStubProtocol.statusCode = 500
        InlineStubProtocol.body = Data()
        InlineStubProtocol.requestCount = 0
        let session = makeSession(retryConfiguration: .enabled(maximumRetryCount: 2, baseDelay: 0.01))

        await #expect(throws: CDYahooKitError.self) {
            let _: StubResponse = try await session.perform(URLRequest(url: URL(string: "https://example.com/c")!))
        }
        #expect(InlineStubProtocol.requestCount == 3)
    }

    @Test("throws apiError when the response root is a Yahoo <error> envelope")
    func throwsApiErrorForErrorEnvelope() async throws {
        InlineStubProtocol.statusCode = 200
        InlineStubProtocol.body = Data("<error><description>Invalid league key.</description></error>".utf8)
        let session = makeSession()

        let thrown = try await #require(throws: CDYahooKitError.self) {
            let _: StubResponse = try await session.perform(URLRequest(url: URL(string: "https://example.com/d")!))
        }
        #expect(thrown.errorDescription == "Invalid league key.")
    }
}
