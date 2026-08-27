//
//  CDYahooURLSessionTests.swift
//  CDYahooKitTests
//

import CDYahooKitTesting
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

@Suite("CDYahooURLSession")
struct CDYahooURLSessionTests {

    private func makeSession(retryConfiguration: CDYahooRetryConfiguration = .disabled,
                             cacheConfiguration: CDYahooCacheConfiguration = .disabled) -> CDYahooURLSession {
        let configuration = URLSessionConfiguration.ephemeral
        configuration.protocolClasses = [CDYahooMockURLProtocol.self]
        return CDYahooURLSession(session: URLSession(configuration: configuration),
                                 retryConfiguration: retryConfiguration,
                                 cacheConfiguration: cacheConfiguration)
    }

    @Test("decodes a successful XML response into the requested type")
    func decodesSuccessfulResponse() async throws {
        let url = try #require(URL(string: "https://example.com/CDYahooURLSessionTests/decodesSuccessfulResponse"))
        CDYahooMockURLProtocol.register(
            stub: .init(statusCode: 200, data: Data("<root><value>hello</value></root>".utf8)),
            for: url
        )
        let session = makeSession()

        let result: StubResponse = try await session.perform(URLRequest(url: url))
        #expect(result.value == "hello")
    }

    @Test("throws for a non-2xx HTTP status")
    func throwsForNon2xxStatus() async throws {
        let url = try #require(URL(string: "https://example.com/CDYahooURLSessionTests/throwsForNon2xxStatus"))
        CDYahooMockURLProtocol.register(stub: .init(statusCode: 404, data: Data()), for: url)
        let session = makeSession()

        await #expect(throws: CDYahooKitError.self) {
            let _: StubResponse = try await session.perform(URLRequest(url: url))
        }
    }

    @Test("retries the configured number of times before giving up")
    func retriesOnFailure() async throws {
        let url = try #require(URL(string: "https://example.com/CDYahooURLSessionTests/retriesOnFailure"))
        CDYahooMockURLProtocol.register(
            stubs: [
                .init(statusCode: 500, data: Data()),
                .init(statusCode: 500, data: Data()),
                .init(statusCode: 500, data: Data())
            ],
            for: url
        )
        let session = makeSession(retryConfiguration: .enabled(maximumRetryCount: 2, baseDelay: 0.01))

        await #expect(throws: CDYahooKitError.self) {
            let _: StubResponse = try await session.perform(URLRequest(url: url))
        }
        #expect(CDYahooMockURLProtocol.requestCount(for: url) == 3)
    }

    @Test("throws apiError when a non-2xx response is Yahoo's <error> envelope")
    func throwsApiErrorForErrorEnvelope() async throws {
        let url = try #require(URL(string: "https://example.com/CDYahooURLSessionTests/throwsApiErrorForErrorEnvelope"))
        CDYahooMockURLProtocol.register(
            stub: .init(statusCode: 400, data: Data("<error><description>Invalid league key.</description></error>".utf8)),
            for: url
        )
        let session = makeSession()

        let thrown = try await #require(throws: CDYahooKitError.self) {
            let _: StubResponse = try await session.perform(URLRequest(url: url))
        }
        #expect(thrown.errorDescription == "Invalid league key.")
    }

    @Test("throws invalidRequest for a non-2xx response with a non-error-envelope body")
    func throwsInvalidRequestForPlainNon2xx() async throws {
        let url = try #require(URL(string: "https://example.com/CDYahooURLSessionTests/throwsInvalidRequestForPlainNon2xx"))
        CDYahooMockURLProtocol.register(
            stub: .init(statusCode: 500, data: Data("Internal Server Error".utf8)),
            for: url
        )
        let session = makeSession()

        let thrown = try await #require(throws: CDYahooKitError.self) {
            let _: StubResponse = try await session.perform(URLRequest(url: url))
        }
        guard case .invalidRequest = thrown else {
            Issue.record("Expected .invalidRequest, got \(thrown)")
            return
        }
    }

    @Test("does not retry a 4xx response — it can never succeed on retry")
    func doesNotRetry4xxResponse() async throws {
        let url = try #require(URL(string: "https://example.com/CDYahooURLSessionTests/doesNotRetry4xxResponse"))
        CDYahooMockURLProtocol.register(stub: .init(statusCode: 404, data: Data()), for: url)
        let session = makeSession(retryConfiguration: .enabled(maximumRetryCount: 2, baseDelay: 0.01))

        await #expect(throws: CDYahooKitError.self) {
            let _: StubResponse = try await session.perform(URLRequest(url: url))
        }
        #expect(CDYahooMockURLProtocol.requestCount(for: url) == 1)
    }

    @Test("does not retry a Yahoo <error> envelope even when paired with a 5xx status")
    func doesNotRetryApiErrorEnvelope() async throws {
        let url = try #require(URL(string: "https://example.com/CDYahooURLSessionTests/doesNotRetryApiErrorEnvelope"))
        CDYahooMockURLProtocol.register(
            stub: .init(statusCode: 500, data: Data("<error><description>Service temporarily overloaded.</description></error>".utf8)),
            for: url
        )
        let session = makeSession(retryConfiguration: .enabled(maximumRetryCount: 2, baseDelay: 0.01))

        await #expect(throws: CDYahooKitError.self) {
            let _: StubResponse = try await session.perform(URLRequest(url: url))
        }
        // A 500 status is transient in principle, but once the body parses as Yahoo's <error>
        // envelope, retrying is pointless — the API is telling us definitively what's wrong.
        #expect(CDYahooMockURLProtocol.requestCount(for: url) == 1)
    }

    @Test("cache entries for the same URL with different Authorization headers do not collide")
    func cacheKeyIncludesAuthorizationHeader() async throws {
        let url = try #require(URL(string: "https://example.com/CDYahooURLSessionTests/cacheKeyIncludesAuthorizationHeader"))
        let session = makeSession(cacheConfiguration: .enabled(timeToLive: 60))

        CDYahooMockURLProtocol.register(
            stub: .init(statusCode: 200, data: Data("<root><value>bodyA</value></root>".utf8)),
            for: url
        )
        var requestA = URLRequest(url: url)
        requestA.setValue("Bearer token-a", forHTTPHeaderField: "Authorization")
        let resultA: StubResponse = try await session.perform(requestA)
        #expect(resultA.value == "bodyA")

        // Re-register a different body at the same URL. If the cache key were URL-only, the
        // second request (different Authorization header) would incorrectly be served the
        // cached "bodyA" response instead of hitting the stub and getting "bodyB".
        CDYahooMockURLProtocol.register(
            stub: .init(statusCode: 200, data: Data("<root><value>bodyB</value></root>".utf8)),
            for: url
        )
        var requestB = URLRequest(url: url)
        requestB.setValue("Bearer token-b", forHTTPHeaderField: "Authorization")
        let resultB: StubResponse = try await session.perform(requestB)
        #expect(resultB.value == "bodyB")
    }
}
