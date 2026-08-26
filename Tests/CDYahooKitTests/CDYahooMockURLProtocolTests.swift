//
//  CDYahooMockURLProtocolTests.swift
//  CDYahooKitTests
//

import CDYahooKitTesting
import Foundation
import Testing
@testable import CDYahooKit

@Suite("CDYahooMockURLProtocol")
struct CDYahooMockURLProtocolTests {

    @Test("register(stub:for:) serves the stub to any request for that URL")
    func registeredStubIsServed() async throws {
        let url = try #require(URL(string: "https://example.com/CDYahooMockURLProtocolTests/registered"))
        CDYahooMockURLProtocol.register(stub: .init(statusCode: 200, data: Data("ok".utf8)), for: url)

        let session = CDYahooMockURLProtocol.makeSession()
        let (data, response) = try await session.data(for: URLRequest(url: url))

        #expect((response as? HTTPURLResponse)?.statusCode == 200)
        #expect(data == Data("ok".utf8))
    }

    @Test("register(stubs:for:) serves stubs in order, then repeats the last one")
    func stubSequenceRepeatsLastEntry() async throws {
        let url = try #require(URL(string: "https://example.com/CDYahooMockURLProtocolTests/sequence"))
        CDYahooMockURLProtocol.register(stubs: [.init(statusCode: 500), .init(statusCode: 200)], for: url)

        let session = CDYahooMockURLProtocol.makeSession()
        let first = try await session.data(for: URLRequest(url: url))
        let second = try await session.data(for: URLRequest(url: url))
        let third = try await session.data(for: URLRequest(url: url))

        #expect((first.1 as? HTTPURLResponse)?.statusCode == 500)
        #expect((second.1 as? HTTPURLResponse)?.statusCode == 200)
        #expect((third.1 as? HTTPURLResponse)?.statusCode == 200)
        #expect(CDYahooMockURLProtocol.requestCount(for: url) == 3)
    }
}
