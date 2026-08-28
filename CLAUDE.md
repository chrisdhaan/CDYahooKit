# CDYahooKit — Claude Code Context

## Project Overview

CDYahooKit is a pure-Swift, zero-dependency wrapper for the **Yahoo Fantasy Sports API**, with
**Sign In With Yahoo** (OAuth 2.0 authorization-code flow + PKCE) for authentication. It targets
iOS 15+, macOS 12+, tvOS 15+, watchOS 8+, and visionOS 1+, uses async/await throughout, and
stores OAuth tokens in the keychain with silent refresh.

**Key characteristics:**

- No external runtime dependencies (Foundation, Security, and — where available —
  AuthenticationServices only). The only SPM dependency is `swift-docc-plugin`, used for docs.
- Read-only coverage of the Fantasy Sports API: a user's games/leagues, league metadata,
  standings, team rosters, the league player pool, the weekly scoreboard, and league
  transactions. No write endpoints in v1.
- The Fantasy Sports API is **XML-native**. CDYahooKit parses XML directly through its own small
  tree parser rather than using Yahoo's inconsistent `format=json` parameter.
- Comprehensive test suite using the **Swift Testing** framework (`@Suite` / `@Test` / `#expect`).
- DocC documentation catalog; `docs/` is the generated static site served by GitHub Pages.

## Scope

CDYahooKit wraps the Yahoo Fantasy Sports API only. Every other Yahoo developer API the original
(pre-rewrite) library targeted has been shut down: YQL and the Yahoo Weather API (2019), the
Social Directory / Contacts API (2020), the official Yahoo Finance API (2017), and BOSS Search
(2016). The only consumer-facing surface left on `developer.yahoo.com` is the Fantasy Sports API
and Sign In With Yahoo — this library wraps both. Don't add modules for the retired APIs.

## Repository Layout

```
CDYahooKit/
├── CDYahooKit.xcodeproj/              # Root native Xcode project (one framework target/scheme per platform)
├── CDYahooKit.xcworkspace/            # Ties CDYahooKit.xcodeproj + Example/iOS Example.xcodeproj together
├── CDYahooKit/Assets/.gitkeep         # Placeholder asset-catalog dir for the native Xcode targets
├── Source/                           # Core library (Swift) — 29 files
│   ├── CDYahooFantasyAPIClient.swift  # Primary public API client (@MainActor)
│   ├── CDYahooRouter.swift            # Fantasy endpoint enum → URLRequest (fantasy/v2/* paths)
│   ├── CDYahooURLSession.swift        # Request execution: cache / retry / adapters / monitors, then parse
│   ├── CDYahooOAuthClient.swift       # OAuth 2.0 + PKCE, token exchange, silent refresh (an `actor`)
│   ├── CDYahooOAuthRouter.swift       # OAuth endpoint routing (authorize / token)
│   ├── CDYahooOAuthCredential.swift   # Decodes the OAuth token endpoint's JSON response (Codable, internal)
│   ├── CDYahooAuthSession.swift       # ASWebAuthenticationSession async/await wrapper (iOS/macOS/visionOS)
│   ├── CDYahooPKCE.swift              # PKCE code verifier / challenge (S256)
│   ├── CDYahooKeychain.swift          # Internal keychain helper — plain-string SecItem entries, AfterFirstUnlockThisDeviceOnly
│   ├── CDYahooXMLTreeBuilder.swift    # XMLParser delegate → CDYahooXMLNode tree
│   ├── CDYahooXMLNode.swift           # Parsed XML node (element name, attributes, children, text)
│   ├── CDYahooXMLDecodable.swift      # init(node:) protocol + node-traversal helpers
│   ├── CDYahooRequestAdapter.swift    # Request adapter hook protocol
│   ├── CDYahooEventMonitor.swift      # Event monitor hook protocol
│   ├── CDYahooResponseCache.swift     # In-memory GET response cache
│   ├── CDYahooCacheConfiguration.swift / CDYahooRetryConfiguration.swift
│   ├── CDYahooKitError.swift          # Public error enum
│   ├── CDYahooConstants.swift         # Base URLs (fantasy + OAuth)
│   ├── CDYahoo{Game,League,Player}.swift               # Shared models
│   ├── CDYahoo{UserGames,League,LeagueStandings,TeamRoster,LeaguePlayers,LeagueScoreboard,LeagueTransactions}Response.swift
│   ├── Testing/CDYahooMockURLProtocol.swift            # Ships in the CDYahooKitTesting product
│   └── CDYahooKit.docc/               # DocC catalog (CDYahooKit.md landing page, GettingStarted.md)
├── Tests/CDYahooKitTests/            # Swift Testing suites (12 @Suite, 54 @Test)
│   └── Fixtures/*.xml                 # Hand-authored response fixtures (see Known Limitations)
├── Example/                          # Example iOS app
│   ├── iOS Example.xcodeproj/        # References the framework via a LOCAL SPM package (relativePath = "..")
│   ├── Secrets.xcconfig.example      # Copy to Secrets.xcconfig (gitignored); fill in Yahoo app credentials
│   └── Source/                       # AppDelegate, SceneDelegate, ViewController, LeagueList / Standings VCs
├── Documentation/                   # ARCHITECTURE.md, Usage.md
├── docs/                            # DocC-generated static site (committed only via release-tied docs commits)
├── scripts/generate-docs.sh         # DocC build + .nojekyll / index.html redirect / 404.html fixups
├── Package.swift                    # SPM manifest (swift-tools-version:6.0, swiftLanguageModes [.v6])
├── .swiftlint.yml / .swiftformat / .swiftformat-version   # Lint + format config (pinned SwiftFormat 0.62.1)
├── .github/workflows/ci.yml
├── README.md / CONTRIBUTING.md / CLAUDE.md / CHANGELOG.md / LICENSE
```

**Two parallel project representations, by design:** `Package.swift` (SPM — the source of truth,
used for `swift build` / `swift test` and for consumption) and `CDYahooKit.xcodeproj` (a native
multi-platform Xcode project with one framework target + shared scheme per platform, driven only
by CI's `xcodebuild` jobs and for local multi-platform build verification — it does not build or
run the tests). Adding a file to `Source/` is picked up automatically by SPM's file scan, but
must be added **manually** to `CDYahooKit.xcodeproj/project.pbxproj`
(`PBXFileReference` / `PBXBuildFile` / `PBXSourcesBuildPhase`) for each platform target if it
needs to build there. Unlike CDOAuth1Kit, the **Example app does not cross-reference the root
Xcode project** — it uses an `XCLocalSwiftPackageReference` pointing at the repo root
(`relativePath = ".."`), so there are no shared target GUIDs to preserve when regenerating
`CDYahooKit.xcodeproj`.

## Platform & Swift Support

| Platform | Minimum OS | Swift | Notes |
|----------|-----------|-------|-------|
| iOS      | 15.0+     | 6.0+  | Full OAuth web flow via `ASWebAuthenticationSession` |
| macOS    | 12.0+     | 6.0+  | Full OAuth web flow |
| tvOS     | 15.0+     | 6.0+  | **No** `ASWebAuthenticationSession` — build the auth URL and complete the flow out of band |
| watchOS  | 8.0+      | 6.0+  | Same as tvOS |
| visionOS | 1.0+      | 6.0+  | Full OAuth web flow |

`ASWebAuthenticationSession` is unavailable on tvOS/watchOS; the whole of `CDYahooAuthSession` is
gated with `#if os(iOS) || os(macOS) || os(visionOS)`. This was a real CI-surfaced issue during
the rewrite — an SPM-only pipeline that only builds for the host never catches it.

## Architecture Summary

```
CDYahooFantasyAPIClient (@MainActor, public API)
  ├─ CDYahooOAuthClient         — OAuth 2.0 + PKCE; validAccessToken() refreshes silently; keychain-backed
  │     ├─ CDYahooOAuthRouter / CDYahooPKCE / CDYahooOAuthCredential / CDYahooKeychain
  │     └─ CDYahooAuthSession   — ASWebAuthenticationSession async/await wrapper (interactive sign-in)
  ├─ CDYahooRouter              — enum case → URLRequest against fantasy/v2/*
  └─ CDYahooURLSession
        ├─ applies request adapters, event monitors, retry, and the response cache
        ├─ CDYahooXMLTreeBuilder → CDYahooXMLNode tree
        └─ hands the root node to the response type's init(node:) (CDYahooXMLDecodable)
```

Each response model implements a thin `init(node:)` against the shared `CDYahooXMLNode` tree
instead of a bespoke `XMLParser` delegate — one shared parsing engine, many small decoders.

### Why XML, not `format=json`

The Fantasy Sports API is XML-native. Its `format=json` output renders single items vs. arrays
differently depending on cardinality, and any write request must be XML regardless. CDYahooKit
treats XML as the source of truth end to end.

### Why OAuth 2.0, not CDOAuth1Kit

The Fantasy Sports API requires OAuth 2.0; OAuth 1.0a is no longer usable for new API access.
`CDYahooAuthSession` mirrors CDOAuth1Kit's `CDOAuth1AuthSession` shape, but carries an OAuth 2.0
authorization code (not a 1.0a verifier), and `CDYahooOAuthClient` owns PKCE and silent refresh,
which OAuth 1.0a has no equivalent of.

## Building

```bash
swift build
swift build -c release
```

Xcode (SPM): File → Add Packages → `https://github.com/chrisdhaan/CDYahooKit.git`

Multi-platform verification: open `CDYahooKit.xcworkspace` and build the per-platform schemes,
or run the `xcodebuild` invocations from `.github/workflows/ci.yml`.

## Running Tests

```bash
swift test
swift test --filter CDYahooXMLTreeBuilderTests
swift test -v
```

Tests use **Swift Testing** (`@Suite`, `@Test`, `#expect`), not XCTest. Network is stubbed with
`CDYahooMockURLProtocol` (shipped in the `CDYahooKitTesting` product so downstream apps can use it
too). Response-parsing suites load the XML files in `Tests/CDYahooKitTests/Fixtures/`.

## Generating Documentation

CDYahooKit uses **DocC**.

```bash
bash scripts/generate-docs.sh
```

This runs the same `swift package generate-documentation` invocation CI uses, then writes
`docs/.nojekyll`, the root `index.html` redirect, and `404.html` for GitHub Pages. Hosted at
`https://chrisdhaan.github.io/CDYahooKit/documentation/cdyahookit/`.

**Doc requirements:** every public symbol needs a `///` comment — the `documentation` CI job
fails the build on any DocC `warning:` line. `docs/` is regenerated and committed **only** in
dedicated, release-tied commits (`docs: regenerate DocC site for vX.Y.Z`) — never bundled into a
feature PR.

## CI/CD Pipeline (GitHub Actions)

`.github/workflows/ci.yml`. Triggered by changes to `Source/`, `Tests/`, `Package.swift`,
`CDYahooKit.xcodeproj/`, `Example/`, or the workflow itself.

| Job | Runner(s) | Purpose |
|-----|-----------|---------|
| `iOS` / `macOS` / `tvOS` / `watchOS` / `visionOS` | `macos-26` × several Xcode versions + `macos-15` | `xcodebuild clean build` per platform scheme, both `Debug` and `Release` (build only — tests run in the `SPM` job) |
| `Catalyst` | `macos-15` | iOS scheme built for Mac Catalyst |
| `Example` | `macos-15` | Builds `Example/iOS Example.xcodeproj` (placeholder `Secrets.xcconfig` copied first) |
| `SPM` | `macos-15` | `swift test -c debug` |
| `swiftlint` | `macos-15` | `swiftlint lint --strict` |
| `swiftformat` | `macos-15` | Verifies the installed version matches `.swiftformat-version` (0.62.1), then `swiftformat Source Tests --lint` |
| `documentation` | `macos-15` | DocC build; fails on any `warning:` line |
| `codeql` | `macos-15` | CodeQL security analysis |

Full sibling-parity matrix (multiple Xcode versions per platform) is deliberate — see the
project memory. Don't trim it to one Xcode per platform.

## Code Style

- **SwiftLint** (`.swiftlint.yml`): line length warning 149 / error 200; `file_length` 300;
  `function_body_length` 60; `type_body_length` 200. Lints `Source` and `Example/Source`.
- **SwiftFormat** (`.swiftformat`): 4-space indent, `--maxwidth 149`, LF line endings,
  `--wraparguments preserve` (no auto code expansion), a set of `--disable`d rules that preserve
  existing conventions. Version is pinned in `.swiftformat-version`.

Run before committing:

```bash
swiftformat Source Tests
swiftlint lint --strict
swift build
swift test
```

## Key Design Decisions

1. **Zero runtime dependencies** — Foundation / Security / AuthenticationServices only.
2. **Async/await everywhere** — no completion handlers.
3. **XML-first parsing** — one `CDYahooXMLNode` engine; models implement `init(node:)`.
4. **OAuth 2.0 + PKCE**, keychain-backed tokens, silent refresh in `validAccessToken()`.
5. **`@MainActor` public client**; `CDYahooKitError` is `@unchecked Sendable` (erased `any Error`
   payloads), mirroring `CDYelpRouter`'s rationale.
6. **Read-only v1** — write endpoints (roster changes, add/drop, waivers, trades) are tracked
   for a later release, not in scope now.
7. **DocC, not Jazzy**; **Swift Testing**, not XCTest.
8. **`.enableUpcomingFeature("ExistentialAny")`** on both library targets; `swiftLanguageModes: [.v6]`.

## Known Limitations / Tech Debt

1. **Hand-authored XML fixtures.** `Tests/CDYahooKitTests/Fixtures/*.xml` were written by hand,
   not captured from a real Yahoo Developer Network account (none was available during the
   rewrite). They're internally consistent with the parser but unverified against the API's
   actual response shape. Revisit if real API access becomes available — this is also why
   `Documentation/API_SCHEMA.md` is a planned follow-up.
2. **No interactive OAuth on tvOS/watchOS** — `ASWebAuthenticationSession` is unavailable there;
   callers must complete the web step out of band and hand the code back.

## Common Tasks

### Add a new Fantasy resource / endpoint

1. Add a `CDYahooRouter` case that builds the `fantasy/v2/...` path + query.
2. Add the response model(s) with `init(node:)` conforming to `CDYahooXMLDecodable`.
3. Add a `public func fetch…(…) async throws -> …Response` on `CDYahooFantasyAPIClient` that goes
   through `authorizedRequest(_:)` → `session.perform(_:)`.
4. Add an XML fixture + a parser suite in `Tests/CDYahooKitTests/`.
5. If the file must build in the native Xcode targets, add it to `CDYahooKit.xcodeproj`.
6. Add `///` docs and a `- ``Symbol``` line under the right `## Topics` section in
   `Source/CDYahooKit.docc/CDYahooKit.md`.
7. `swiftformat Source Tests && swiftlint lint --strict && swift test`.

### Add a test

Create a file under `Tests/CDYahooKitTests/`, use `@Suite` / `@Test` / `#expect`, run
`swift test --filter <name>`.

### Update documentation

Edit `///` comments and/or `Documentation/*.md`. Preview with `bash scripts/generate-docs.sh`.
Do **not** commit the regenerated `docs/` in the same PR as the code change.

### Release a new version

Follows the shared sibling convention (CDOAuth1Kit / CDUntappdKit / CDYelpFusionKit):

1. Update `CHANGELOG.md`: heading is a link to its own release —
   `## [X.Y.Z](https://github.com/chrisdhaan/CDYahooKit/releases/tag/X.Y.Z)`, then a blank line,
   then `Released on YYYY-MM-DD.`, then `### Added` / `### Changed` / `### Removed` sections.
2. Annotated tag on the release commit: `git tag -a X.Y.Z -m "X.Y.Z"` (no `v` prefix), push.
3. `gh release create X.Y.Z --title X.Y.Z --notes-file <file>` where the file is the CHANGELOG
   entry body (from `Released on…` onward). Non-draft, non-prerelease.
4. Separately, after the tagged commit: `bash scripts/generate-docs.sh`, commit as
   `docs: regenerate DocC site for vX.Y.Z`, push (untagged).
5. GitHub Pages: source = `master` branch, `/docs` path (already enabled).

## Further Reading

- [Yahoo Fantasy Sports API docs](https://developer.yahoo.com/fantasysports/guide/)
- [Documentation/ARCHITECTURE.md](Documentation/ARCHITECTURE.md)
- [Documentation/Usage.md](Documentation/Usage.md)
- [CONTRIBUTING.md](CONTRIBUTING.md)
