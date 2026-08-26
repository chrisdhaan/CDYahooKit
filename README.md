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

`Example/Source/` and `Example/Resources/` contain Swift source demonstrating the full Sign In
With Yahoo + Fantasy Sports flow: OAuth 2.0 login, fetching the signed-in user's fantasy leagues,
and displaying league standings.

This source is not wired into a buildable Xcode project — no `.xcodeproj`/`.xcworkspace` is
checked into this repository. To run the example yourself:

1. Create a new iOS App project in Xcode.
2. Add the files under `Example/Source/` and `Example/Resources/` to it.
3. Add CDYahooKit as a local Swift Package dependency (File → Add Packages → Add Local...,
   pointing at this repository's root).
4. Copy `Example/Secrets.xcconfig.example` to `Example/Secrets.xcconfig` and fill in your own
   `clientId`/`clientSecret`/`redirectUrl` from the [Yahoo Developer Network](https://developer.yahoo.com/apps/),
   then reference that xcconfig from your new project's build settings (or wire the same values
   in however your project reads configuration).

## Scope

CDYahooKit wraps the Yahoo Fantasy Sports API only. Every other Yahoo developer API this
library once targeted (Social, YQL, Weather, Finance, BOSS) has since been shut down — see
`docs/superpowers/specs/2026-08-24-cdyahookit-fantasy-sports-rewrite-design.md` for the audit.

## Author

Christopher de Haan, contact@christopherdehaan.me

## License

CDYahooKit is available under the MIT license. See the LICENSE file for more info.
