# Changelog

## [Unreleased]

### Changed

- Aligned the LICENSE file with this project's established standards, and refreshed all Xcode scheme files (restoring a missing macro-expansion configuration, bumping the recorded Xcode version) after finding them years out of date.
- Tightened the `file_length`, `function_body_length`, and `type_body_length` SwiftLint limits to a consistent baseline (`line_length` was already aligned). No violations resulted — the codebase already fit comfortably within the tightened limits.

## [1.1.0](https://github.com/chrisdhaan/CDYahooKit/releases/tag/1.1.0)

Released on 2026-08-28.

Expanded read coverage of the Fantasy Sports API: league settings, draft results (league- and
team-scoped), team matchups and stat totals, `game/{game_key}` rule metadata, and player-pool
filtering, sorting, pagination, and sub-resources. No write endpoints — v1 remains read-only.

### Added
- `CDYahooFantasyAPIClient.fetchLeaguePlayers(leagueKey:query:)`, extending the
  `league/{league_key}/players` collection with the modifiers the Fantasy API supports: the
  `;out=stats`, `;out=percent_owned`, and `;out=ownership` sub-resource selectors, `;position=`,
  `;status=`, `;search=`, and `;sort=` filters, and `;start=` / `;count=` pagination. New public
  types `CDYahooLeaguePlayersQuery`, the `CDYahooPlayerSubresource` option set, and the
  `CDYahooPlayerStatusFilter` and `CDYahooPlayersSort` enums. `CDYahooPlayer` gained optional
  `percentOwned`, `ownership` (`CDYahooPlayerOwnership`), and `stats` (`[CDYahooPlayerStat]`)
  fields, populated only when the matching sub-resource is requested.
- `CDYahooFantasyAPIClient.fetchGameStatCategories(gameKey:)`,
  `fetchGamePositionTypes(gameKey:)`, `fetchGameRosterPositions(gameKey:)`, and
  `fetchGameWeeks(gameKey:)`, wrapping the four `game/{game_key}` metadata sub-resources that
  describe a fantasy game's rules. New public types `CDYahooGameStatCategoriesResponse` /
  `CDYahooGameStatCategory`, `CDYahooGamePositionTypesResponse` / `CDYahooPositionType`,
  `CDYahooGameRosterPositionsResponse` / `CDYahooGameRosterPosition`, and
  `CDYahooGameWeeksResponse` / `CDYahooGameWeek`. `gameKey` accepts a Yahoo game key or game code.
- `CDYahooFantasyAPIClient.fetchTeamMatchups(teamKey:weeks:)` and
  `fetchTeamStats(teamKey:coverage:)`, wrapping the `team/{team_key}/matchups` (optional
  `;weeks=` filter) and `team/{team_key}/stats` (`;type=season` or `;type=week;week=`)
  sub-resources. New public types `CDYahooTeamMatchupsResponse`, `CDYahooTeamStatsResponse`,
  `CDYahooTeamStats`, `CDYahooTeamStat`, and the `CDYahooTeamStatsCoverage` coverage-window enum
  (`.season` / `.week(_:)`). `CDYahooMatchup` gained optional `weekStart`, `weekEnd`,
  `isPlayoffs`, `isConsolation`, `isTied`, and `winnerTeamKey` fields (populated from the team
  `matchups` payload; `nil` from the league `scoreboard`), and `CDYahooMatchupTeamScore` gained
  an optional `projectedPoints`.
- `CDYahooFantasyAPIClient.fetchLeagueSettings(leagueKey:)`, wrapping the
  `league/{league_key}/settings` sub-resource: scoring type, roster positions, the stat
  categories the league scores and their point modifiers, and its waiver, trade, and playoff
  rules. New public types `CDYahooLeagueSettingsResponse`, `CDYahooLeagueSettings`,
  `CDYahooRosterPosition`, `CDYahooStatCategory`, and `CDYahooStatModifier` — stat categories and
  modifiers are exposed as parallel lists joined on `statId`.
- `CDYahooFantasyAPIClient.fetchLeagueDraftResults(leagueKey:)` and
  `fetchTeamDraftResults(teamKey:)`, wrapping the `league/{league_key}/draftresults` and
  `team/{team_key}/draftresults` sub-resources: each pick's round, pick number, drafting team,
  player taken, and (auction drafts only) winning bid. New public types
  `CDYahooLeagueDraftResultsResponse`, `CDYahooTeamDraftResultsResponse`, and the shared
  `CDYahooDraftResult`.

### Changed
- `CDYahooRouter.players` now takes a `CDYahooLeaguePlayersQuery` instead of a bare `start: Int?`.
  `CDYahooFantasyAPIClient.fetchLeaguePlayers(leagueKey:start:)` is deprecated in favor of
  `fetchLeaguePlayers(leagueKey:query:)`; the `start:` form still works and forwards to it.
- `Documentation/API_SCHEMA.md`, `Documentation/Usage.md`, and `Documentation/ARCHITECTURE.md`
  extended with the league settings, draft results, team matchups/stats, game metadata, and
  league-players collection-modifier resources.
- Example app: added **League Settings**, **League Draft Results**, **Team Draft Results**,
  **Team Matchups**, **Team Stats**, **Game Stat Categories**, **Game Position Types**,
  **Game Roster Positions**, and **Game Weeks** rows to the endpoint list.

### Fixed
- DocC `GettingStarted` article: the `oAuthClient.authorizationURL(codeChallenge:state:)` call now
  shows the required `await` (the method is `actor`-isolated), so the snippet compiles as written.

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
