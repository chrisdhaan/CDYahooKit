# CDYahooKit

[![CI Status](https://github.com/chrisdhaan/CDYahooKit/actions/workflows/ci.yml/badge.svg)](https://github.com/chrisdhaan/CDYahooKit/actions/workflows/ci.yml)
[![Swift](https://img.shields.io/badge/Swift-6.0%2B-orange?style=flat)](https://swift.org)
[![SPM](https://img.shields.io/badge/Swift_Package_Manager-compatible-orange?style=flat)](https://swift.org/package-manager/)
[![License](https://img.shields.io/badge/License-MIT-blue.svg?style=flat)](LICENSE)

---

A Swift wrapper for the Yahoo Fantasy Sports API, with Sign In With Yahoo (OAuth 2.0 / PKCE)
for authentication. No external dependencies.

## Features

- [x] Yahoo Fantasy Sports API: games, leagues, standings, rosters, players, scoreboard, transactions (read-only)
- [x] Sign In With Yahoo: OAuth 2.0 authorization code flow with PKCE
- [x] Keychain-backed token storage with silent refresh
- [x] async/await API
- [x] Zero external dependencies

## Requirements

| Platform | Minimum OS | Swift | Installation |
|----------|-----------|-------|--------------|
| iOS      | 15.0+     | 6.0+  | SPM          |
| macOS    | 12.0+     | 6.0+  | SPM          |
| tvOS     | 15.0+     | 6.0+  | SPM          |
| watchOS  | 8.0+      | 6.0+  | SPM          |
| visionOS | 1.0+      | 6.0+  | SPM          |

## Installation

### Swift Package Manager

Add CDYahooKit to your `Package.swift`:

```swift
.package(url: "https://github.com/chrisdhaan/CDYahooKit.git", from: "1.0.0")
```

Or in Xcode: File → Add Packages → Enter `https://github.com/chrisdhaan/CDYahooKit.git`

## Usage

See [Documentation/Usage.md](Documentation/Usage.md) for comprehensive usage examples, or browse
the full [API documentation](https://chrisdhaan.github.io/CDYahooKit/documentation/cdyahookit/).

## Example App

`Example/iOS Example.xcodeproj` is a real, buildable iOS app project demonstrating the full Sign
In With Yahoo + Fantasy Sports flow: OAuth 2.0 login, fetching the signed-in user's fantasy
leagues, and displaying league standings. It depends on CDYahooKit as a local Swift Package
reference to this repository's root, so it builds standalone with no extra wiring.

To run it:

1. Copy `Example/Secrets.xcconfig.example` to `Example/Secrets.xcconfig` and fill in your own
   `clientId`/`clientSecret`/`redirectUrl` from the [Yahoo Developer Network](https://developer.yahoo.com/apps/).
2. Open `Example/iOS Example.xcodeproj` in Xcode and run the `iOS Example` scheme.

## Scope

CDYahooKit wraps the Yahoo Fantasy Sports API only. Every other Yahoo developer API this
library once targeted has since been shut down: YQL and the Yahoo Weather API (retired
2019-01-03), the Social Directory / Contacts API (EOL'd 2020-06-30), the official Yahoo Finance
API (killed 2017-05-15), and BOSS Search (shut down 2016-03-31). The only consumer-facing
surface left on `developer.yahoo.com` is the Fantasy Sports API and Sign In With Yahoo — this
library wraps both.

## Author

Christopher de Haan, contact@christopherdehaan.me

## License

CDYahooKit is available under the MIT license. See the LICENSE file for more info.
