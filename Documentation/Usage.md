# Usage

## Installation

Add CDYahooKit to your `Package.swift`:

```swift
.package(url: "https://github.com/chrisdhaan/CDYahooKit.git", from: "1.0.0")
```

Or in Xcode: File → Add Packages → Enter `https://github.com/chrisdhaan/CDYahooKit.git`

## Scope

CDYahooKit wraps the Yahoo Fantasy Sports API and Sign In With Yahoo — see the
[README](../README.md#scope) for the full picture of what's covered. v1 is read-only: write
endpoints (roster/lineup changes, waiver claims, trades) aren't covered.

## Authentication, Fetching Data, Testing

See <doc:GettingStarted> in the DocC catalog for a full walkthrough, and `CDYahooKitTesting`'s
`CDYahooMockURLProtocol` for mocking network calls in your own app's tests.
