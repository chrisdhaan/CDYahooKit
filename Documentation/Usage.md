# Usage

## Installation

Add CDYahooKit to your `Package.swift`:

```swift
.package(url: "https://github.com/chrisdhaan/CDYahooKit.git", from: "1.0.0")
```

Or in Xcode: File → Add Packages → Enter `https://github.com/chrisdhaan/CDYahooKit.git`

## Scope

CDYahooKit wraps the Yahoo Fantasy Sports API only — see the design spec
(`docs/superpowers/specs/2026-08-24-cdyahookit-fantasy-sports-rewrite-design.md`) for why
every other Yahoo developer API this library once targeted (Social, YQL, Weather, Finance,
BOSS) has since been shut down.

v1 is read-only. Write endpoints (roster/lineup changes, waiver claims, trades) aren't covered.

## Authentication, Fetching Data, Testing

See <doc:GettingStarted> in the DocC catalog for a full walkthrough, and `CDYahooKitTesting`'s
`CDYahooMockURLProtocol` for mocking network calls in your own app's tests.
