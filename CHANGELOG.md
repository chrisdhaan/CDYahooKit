# Changelog

## Unreleased

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
