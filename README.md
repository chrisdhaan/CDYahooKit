<p align="center">
    <a href="https://github.com/chrisdhaan/CDYahooKit">
        <img src="https://raw.githubusercontent.com/chrisdhaan/CDYahooKit/master/Documentation/cdyahookit.png" alt="CDYahooKit" width="850" />
    </a>
</p>

<p align="center">
    <a href="https://github.com/chrisdhaan/CDYahooKit/actions/workflows/ci.yml">
        <img src="https://github.com/chrisdhaan/CDYahooKit/actions/workflows/ci.yml/badge.svg" alt="CI Status">
    </a>
    <a href="https://github.com/chrisdhaan/CDYahooKit/releases">
        <img src="https://img.shields.io/github/release/chrisdhaan/CDYahooKit.svg" alt="GitHub Release">
    </a>
    <a href="https://www.swift.org">
        <img src="https://img.shields.io/badge/Swift-6.0+-orange?style=flat" alt="Swift Versions">
    </a>
    <a href="https://www.swift.org/package-manager">
        <img src="https://img.shields.io/badge/Swift_Package_Manager-compatible-orange?style=flat" alt="Swift Package Manager Compatible">
    </a>
    <a href="https://github.com/chrisdhaan/CDYahooKit/blob/master/LICENSE">
        <img src="https://img.shields.io/github/license/chrisdhaan/CDYahooKit.svg" alt="License">
    </a>
</p>

A Swift wrapper for the Yahoo Fantasy Sports API, with Sign In With Yahoo (OAuth 2.0 / PKCE)
for authentication. No external dependencies.

## Features

- [x] Yahoo Fantasy Sports API: games, leagues, settings, standings, rosters, players, scoreboard, transactions, draft results (read-only)
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
In With Yahoo + Fantasy Sports flow: OAuth 2.0 + PKCE login, then a row per read-only endpoint —
user games & leagues, league metadata, league settings, standings, team roster, league players,
scoreboard, transactions, and draft results (league- and team-scoped) — each of which runs the
request and pushes a viewer showing the raw, re-indented
XML Yahoo returned (captured through a `CDYahooEventMonitor`). It depends on CDYahooKit as a
local Swift Package reference to this repository's root, so it builds standalone with no extra
wiring.

This app builds its UI programmatically rather than from a storyboard — a deliberate choice,
kept because there is no `.storyboard` XML to hand-maintain alongside the project file.

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
