# Changelog

## [1.0.1](https://github.com/chrisdhaan/CDYahooKit/releases/tag/1.0.1)

Released on 2026-08-27.

A documentation, repository-hygiene, and Example-app release. No library source changed — the
public API is identical to 1.0.0.

### Added
- `Documentation/ARCHITECTURE.md` and `Documentation/Usage.md`, substantially expanded: request
  lifecycle, the OAuth 2.0 + PKCE + silent-refresh flow, the Keychain helper, the XML parsing
  engine, the response-model hierarchy, error handling, concurrency, per-platform auth, and
  worked usage for every `fetch…` method plus retry / cache / adapter / monitor configuration
  and `CDYahooMockURLProtocol`.
- `Documentation/API_SCHEMA.md`: per-resource request URIs and matrix-parameter modifiers,
  annotated response-XML element trees, and element-to-model mapping tables for all seven
  endpoints, with each element flagged as verified against code, verified against Yahoo's
  reference docs, or inferred from the hand-authored fixtures pending real API access.
- `CONTRIBUTING.md`, `CLAUDE.md`, and `.github/` community-health files: issue templates, a pull
  request template, `CODEOWNERS`, `FUNDING`, `SECURITY.md`, and `SUPPORT.md`.
- `CDYahooKit.xcworkspace`, tying `CDYahooKit.xcodeproj` and the Example project together.
- Example app: a `CDYahooKitManager` wrapper, a raw XML response viewer (`XMLPrettyPrinter` and
  `CDYahooKitXMLResponseViewController`), and an `XMLResponseRecorder` `CDYahooEventMonitor` that
  captures the most recent response body.

### Changed
- README restyled with a centered banner and status badges, and image assets added under
  `Documentation/`.
- Example app rebuilt around a single endpoint list that exercises all seven read resources —
  user games, league, standings, team roster, league players, scoreboard, and transactions —
  each pushing a viewer showing the raw, re-indented XML Yahoo returned. Replaces the previous
  bespoke leagues-to-standings drill-down. The Example keeps its programmatic UI (no storyboard)
  by design.
- `MARKETING_VERSION` bumped to 1.0.1 across the `CDYahooKit.xcodeproj` platform targets.

## [1.0.0](https://github.com/chrisdhaan/CDYahooKit/releases/tag/1.0.0)

Released on 2026-08-26.

### Added
- Complete Swift rewrite: Swift Package Manager, DocC documentation, GitHub Actions CI,
  modernized Example app.
- Yahoo Fantasy Sports API: `fetchUserGames`, `fetchLeague`, `fetchLeagueStandings`,
  `fetchTeamRoster`, `fetchLeaguePlayers`, `fetchLeagueScoreboard`, `fetchLeagueTransactions`.
- Sign In With Yahoo: OAuth 2.0 authorization code flow with PKCE, Keychain-backed token
  storage, silent refresh.
- `CDYahooKitTesting` product with `CDYahooMockURLProtocol` for mocking network calls in
  consuming apps' tests.

### Removed
- The Objective-C/CocoaPods implementation and its OAuth 1.0a dependency on CDOAuth1Kit — the
  Yahoo Fantasy Sports API requires OAuth 2.0 for all new API access.
- All Yahoo Social API surface (Contacts, Social Directory) — shut down by Yahoo in 2020.
