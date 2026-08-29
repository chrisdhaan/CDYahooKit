# CDYahooKit Usage Guide

A task-oriented guide to authenticating with Sign In With Yahoo and reading from the Yahoo
Fantasy Sports API. For the architecture behind these calls, see
[ARCHITECTURE.md](ARCHITECTURE.md); for a five-minute version, see `<doc:GettingStarted>` in
the DocC catalog.

## Table of Contents

- [Installation](#installation)
- [Registering Your Yahoo App](#registering-your-yahoo-app)
- [Initialization](#initialization)
- [Authentication](#authentication)
  - [Interactive sign-in (iOS / macOS / visionOS)](#interactive-sign-in-ios--macos--visionos)
  - [Out-of-band sign-in (tvOS / watchOS)](#out-of-band-sign-in-tvos--watchos)
  - [Checking authorization status](#checking-authorization-status)
  - [Token refresh](#token-refresh)
  - [Signing out](#signing-out)
- [Fantasy Sports Keys](#fantasy-sports-keys)
- [Fetch Methods](#fetch-methods)
  - [Fetch the user's games and leagues](#fetch-the-users-games-and-leagues)
  - [Fetch league metadata](#fetch-league-metadata)
  - [Fetch league standings](#fetch-league-standings)
  - [Fetch a team roster](#fetch-a-team-roster)
  - [Fetch the league player pool](#fetch-the-league-player-pool)
  - [Fetch the weekly scoreboard](#fetch-the-weekly-scoreboard)
  - [Fetch league transactions](#fetch-league-transactions)
  - [Fetch league settings](#fetch-league-settings)
  - [Fetch draft results](#fetch-draft-results)
  - [Fetch team matchups and stats](#fetch-team-matchups-and-stats)
  - [Fetch game metadata](#fetch-game-metadata)
- [Error Handling](#error-handling)
- [Configuration](#configuration)
  - [Retry](#retry)
  - [Response cache](#response-cache)
  - [Request adapters](#request-adapters)
  - [Event monitors](#event-monitors)
- [Cancellation](#cancellation)
- [Testing Utilities](#testing-utilities)
- [Platform Notes](#platform-notes)
- [How to Contribute](#how-to-contribute)
- [Further Reading](#further-reading)

---

## Installation

### Swift Package Manager

Add CDYahooKit to your `Package.swift`:

```swift
dependencies: [
    .package(url: "https://github.com/chrisdhaan/CDYahooKit.git", from: "1.0.0")
],
targets: [
    .target(
        name: "MyApp",
        dependencies: [.product(name: "CDYahooKit", package: "CDYahooKit")]
    ),
    .testTarget(
        name: "MyAppTests",
        dependencies: [
            .product(name: "CDYahooKit", package: "CDYahooKit"),
            .product(name: "CDYahooKitTesting", package: "CDYahooKit")
        ]
    )
]
```

Or in Xcode: **File → Add Package Dependencies…** and enter
`https://github.com/chrisdhaan/CDYahooKit.git`.

`CDYahooKitTesting` is a separate product carrying `CDYahooMockURLProtocol` — add it only to
your test target (see [Testing Utilities](#testing-utilities)).

| Platform | Minimum OS | Interactive sign-in |
|----------|-----------|---------------------|
| iOS | 15.0 | ✅ |
| macOS | 12.0 | ✅ |
| tvOS | 15.0 | 🔲 out-of-band only |
| watchOS | 8.0 | 🔲 out-of-band only |
| visionOS | 1.0 | ✅ |

---

## Registering Your Yahoo App

1. Create an app at the [Yahoo Developer Network](https://developer.yahoo.com/apps/).
2. Under **API Permissions**, enable **Fantasy Sports** with **Read** access.
3. Set the **Redirect URI** to a custom URL scheme your app owns, e.g.
   `myapp://callback`.
4. Note the generated **Client ID (Consumer Key)** and **Client Secret (Consumer
   Secret)**.

You'll pass all three — client ID, client secret, redirect URI — to
`CDYahooFantasyAPIClient`.

---

## Initialization

Create one `CDYahooFantasyAPIClient` and hold a strong reference to it for the app's
lifetime (it owns the response cache and the OAuth actor):

```swift
import CDYahooKit

let client = CDYahooFantasyAPIClient(
    clientId: "YOUR_CLIENT_ID",
    clientSecret: "YOUR_CLIENT_SECRET",
    redirectUrl: "myapp://callback"
)
```

The full initializer exposes the optional pipeline configuration
(see [Configuration](#configuration)):

```swift
let client = CDYahooFantasyAPIClient(
    clientId: "YOUR_CLIENT_ID",
    clientSecret: "YOUR_CLIENT_SECRET",
    redirectUrl: "myapp://callback",
    urlSession: URLSession(configuration: .default),
    retryConfiguration: .enabled(maximumRetryCount: 3, baseDelay: 0.5),
    eventMonitors: [MyLoggingMonitor()],
    requestAdapters: [MyHeaderAdapter()],
    cacheConfiguration: .enabled(maximumEntries: 100, timeToLive: 300)
)
```

The OAuth client is reachable as `client.oAuthClient` for driving the sign-in flow.

---

## Authentication

CDYahooKit uses the OAuth 2.0 **authorization-code flow with PKCE**. The shape is the same
on every platform; only the browser step differs.

### Interactive sign-in (iOS / macOS / visionOS)

`CDYahooAuthSession` wraps `ASWebAuthenticationSession`. Because it's constructed with a
`callbackScheme`, the system intercepts the redirect for you — **no `Info.plist` URL-scheme
registration or `SceneDelegate` handling is required** for this flow.

```swift
import CDYahooKit

func signIn(presentationAnchor: ASPresentationAnchor) async throws {
    // 1. PKCE + CSRF state
    let verifier = CDYahooPKCE.makeCodeVerifier()
    let challenge = CDYahooPKCE.codeChallenge(for: verifier)
    let state = UUID().uuidString

    // 2. Build the authorization URL
    let authURL = try await client.oAuthClient.authorizationURL(
        codeChallenge: challenge,
        state: state
    )

    // 3. Present the web sheet and wait for the redirect
    let callbackURL = try await CDYahooAuthSession(presentationAnchor: presentationAnchor)
        .authorize(authorizationURL: authURL, callbackScheme: "myapp")

    // 4. Verify state, extract the code
    let code = try CDYahooAuthSession.extractCode(from: callbackURL, expectedState: state)

    // 5. Exchange the code for a token pair (stored in the Keychain)
    try await client.oAuthClient.authorize(withCode: code, codeVerifier: verifier)
}
```

`callbackScheme` is the scheme portion of your redirect URI (`"myapp"` for
`myapp://callback`).

**Requesting Sign In With Yahoo identity alongside fantasy access.**
`authorizationURL(codeChallenge:state:scope:)` omits `scope` by default, preserving your
app's default grant. Pass an explicit scope string to widen it:

```swift
let authURL = try await client.oAuthClient.authorizationURL(
    codeChallenge: challenge,
    state: state,
    scope: "openid fspt-r"
)
```

**Errors from this flow:**

- The user dismissing the sheet throws `CDYahooKitError.authorizationCancelled`.
- A `state` mismatch (possible CSRF) or a callback with no `code` throws
  `CDYahooKitError.invalidCredentials`.

### Out-of-band sign-in (tvOS / watchOS)

`ASWebAuthenticationSession` isn't available on tvOS 15 or watchOS, so `CDYahooAuthSession`
isn't compiled there. Complete the browser step on another device (a paired phone, a
companion web page, a server-side exchange) and hand the code back:

```swift
let verifier = CDYahooPKCE.makeCodeVerifier()
let challenge = CDYahooPKCE.codeChallenge(for: verifier)
let state = UUID().uuidString

// Display this URL as a QR code / short link for the user to open elsewhere.
let authURL = try await client.oAuthClient.authorizationURL(codeChallenge: challenge, state: state)

// Once you've received the `code` (and verified `state`) out of band:
try await client.oAuthClient.authorize(withCode: code, codeVerifier: verifier)
```

Everything after `authorize(withCode:codeVerifier:)` — silent refresh and all ten fetch
methods — works identically on tvOS and watchOS.

### Checking authorization status

`isAuthorized()` is synchronous and makes no network call — it's a cheap "show the Sign In
button?" check. It returns `true` if the access token is still valid **or** a refresh token
is stored that could mint a new one.

```swift
if await client.oAuthClient.isAuthorized() {
    // proceed to fetch data
} else {
    // present the sign-in flow
}
```

### Token refresh

You never call refresh directly. Every `fetch…` method routes through
`oAuthClient.validAccessToken()`, which:

- returns the stored access token if it's still valid;
- otherwise silently exchanges the refresh token for a new pair and returns the new access
  token;
- coalesces concurrent callers onto a single in-flight refresh (Yahoo rotates the refresh
  token on every use, so parallel refreshes would race);
- throws `CDYahooKitError.invalidCredentials` if there's no refresh token — at which point
  you must re-run the sign-in flow.

If Yahoo rejects the refresh token as dead (`invalid_grant`), CDYahooKit clears the stored
credentials for you, so `isAuthorized()` immediately starts returning `false`.

### Signing out

```swift
await client.oAuthClient.unauthorize()
```

This deletes the access token, refresh token, and expiry from the Keychain.

---

## Fantasy Sports Keys

Yahoo addresses resources by opaque string keys. You rarely construct these by hand — you
read them off a response and pass them to the next call.

| Key | Looks like | Where it comes from |
|-----|-----------|---------------------|
| Game code | `"nfl"`, `"mlb"`, `"nba"`, `"nhl"` | You supply it (`fetchUserGames(gameCode:)`, default `"nfl"`). |
| Game key | `"449"` | `CDYahooGame.gameKey` — the numeric ID of a specific sport-season. |
| League key | `"449.l.123456"` | `CDYahooLeagueSummary.leagueKey` (from `fetchUserGames`) or `CDYahooLeague.leagueKey`. |
| Team key | `"449.l.123456.t.4"` | `CDYahooTeamStanding.teamKey`, `CDYahooMatchupTeamScore.teamKey`, etc. |
| Player key | `"449.p.31883"` | `CDYahooPlayer.playerKey`. |

A typical drill-down: `fetchUserGames` → pick a `leagueKey` → `fetchLeagueStandings` → pick a
`teamKey` → `fetchTeamRoster`.

---

## Fetch Methods

All fetch methods are `async throws`, `@MainActor`-isolated, and return a dedicated response
`struct`. Call them from the main actor or a `Task`.

### Fetch the user's games and leagues

```swift
let response = try await client.fetchUserGames(gameCode: "nfl")

for game in response.games {
    print("\(game.name) \(game.season) — \(game.code)")   // "Football 2025 — nfl"
    for league in game.leagues {
        print("  \(league.name) [\(league.leagueKey)] — \(league.numTeams ?? 0) teams")
    }
}
```

Returns `CDYahooUserGamesResponse` (`games: [CDYahooGame]`). Each `CDYahooGame` has
`gameKey`, `gameId`, `name`, `code`, `season`, and `leagues: [CDYahooLeagueSummary]`
(`leagueKey`, `leagueId`, `name`, `numTeams?`).

### Fetch league metadata

```swift
let response = try await client.fetchLeague(leagueKey: "449.l.123456")
let league = response.league

print(league.name)                       // "My Dynasty League"
print(league.scoringType ?? "")          // "head" / "point" / "roto"
print(league.currentWeek ?? 0)           // 7
print(league.numTeams ?? 0)              // 12
```

Returns `CDYahooLeagueResponse` (`league: CDYahooLeague`). `CDYahooLeague` adds `url?`,
`scoringType?`, `currentWeek?`, and `season?` over the summary type.

### Fetch league standings

```swift
let response = try await client.fetchLeagueStandings(leagueKey: "449.l.123456")

for team in response.teams {
    let record = team.outcomeTotals
    print("\(team.rank ?? 0). \(team.name)  " +
          "\(record?.wins ?? 0)-\(record?.losses ?? 0)-\(record?.ties ?? 0)  " +
          "PF \(team.pointsFor ?? 0)")
}
```

Returns `CDYahooLeagueStandingsResponse` (`leagueKey`, `teams: [CDYahooTeamStanding]`). Each
`CDYahooTeamStanding` has `teamKey`, `teamId`, `name`, `rank?`, `pointsFor?`,
`pointsAgainst?`, and `outcomeTotals?` (`CDYahooTeamOutcomeTotals`: `wins`, `losses`,
`ties`, `percentage`).

### Fetch a team roster

```swift
// Current roster
let current = try await client.fetchTeamRoster(teamKey: "449.l.123456.t.4", week: nil)

// Roster as it was set for week 3
let week3 = try await client.fetchTeamRoster(teamKey: "449.l.123456.t.4", week: 3)

for player in current.players {
    print("\(player.fullName)  \(player.selectedPosition ?? player.displayPosition ?? "")" +
          "  \(player.status ?? "")")   // status: "IR", "O", "Q", …
}
```

Returns `CDYahooTeamRosterResponse` (`teamKey`, `name`, `players: [CDYahooPlayer]`).
`CDYahooPlayer`: `playerKey`, `playerId`, `fullName`, `editorialTeamAbbr?`,
`displayPosition?`, `selectedPosition?`, `status?`, plus `percentOwned?`, `ownership?`, and
`stats?` (populated only when the matching sub-resource is requested — see below).

### Fetch the league player pool

`CDYahooLeaguePlayersQuery` carries every collection modifier; a default `.init()` returns
Yahoo's first unfiltered page.

```swift
// Free-agent wide receivers, sorted by points, first 25, with ownership + season stats.
let query = CDYahooLeaguePlayersQuery(
    subresources: [.percentOwned, .ownership, .stats],
    position: "WR",
    status: .freeAgents,
    sort: .points,
    count: 25
)
let response = try await client.fetchLeaguePlayers(leagueKey: "449.l.123456", query: query)

for player in response.players {
    print(player.fullName,
          player.percentOwned.map { "\($0)% owned" } ?? "",
          player.ownership?.ownershipType ?? "")
}
```

To page, advance `query.start` (a zero-based offset) in steps of `count` (max 25):

```swift
var players: [CDYahooPlayer] = []
var query = CDYahooLeaguePlayersQuery(count: 25)

while true {
    let page = try await client.fetchLeaguePlayers(leagueKey: "449.l.123456", query: query)
    guard !page.players.isEmpty else { break }
    players.append(contentsOf: page.players)
    query.start = players.count
}
```

Returns `CDYahooLeaguePlayersResponse` (`leagueKey`, `players: [CDYahooPlayer]`). The
`;out=stats` / `;out=percent_owned` / `;out=ownership` selectors populate `CDYahooPlayer.stats`
(`[CDYahooPlayerStat]`), `.percentOwned` (`Double`), and `.ownership` (`CDYahooPlayerOwnership`);
those fields are `nil` otherwise. `fetchLeaguePlayers(leagueKey:start:)` is deprecated — it still
works and forwards to the query form.

### Fetch the weekly scoreboard

```swift
// Current week
let response = try await client.fetchLeagueScoreboard(leagueKey: "449.l.123456", week: nil)

for matchup in response.matchups {
    let sides = matchup.teams
        .map { "\($0.name) \($0.totalPoints ?? 0)" }
        .joined(separator: "  vs  ")
    print("Week \(matchup.week) [\(matchup.status)]: \(sides)")
}
```

Returns `CDYahooLeagueScoreboardResponse` (`leagueKey`, `matchups: [CDYahooMatchup]`). Each
`CDYahooMatchup` has `week`, `status` (`"preevent"`, `"midevent"`, `"postevent"`), and
`teams: [CDYahooMatchupTeamScore]` (`teamKey`, `name`, `totalPoints?`).

### Fetch league transactions

```swift
let response = try await client.fetchLeagueTransactions(leagueKey: "449.l.123456")

for txn in response.transactions {
    print("\(txn.type) [\(txn.status)]")   // "add/drop", "trade", "waiver"
    for player in txn.players {
        print("  \(player.transactionType ?? "?") \(player.fullName)" +
              " → \(player.destinationTeamKey ?? "free agents")")
    }
}
```

Returns `CDYahooLeagueTransactionsResponse` (`leagueKey`,
`transactions: [CDYahooTransaction]`). Each `CDYahooTransaction` has `transactionKey`,
`transactionId`, `type`, `status`, and `players: [CDYahooTransactionPlayer]` (`playerKey`,
`fullName`, `transactionType?`, `destinationTeamKey?`).

### Fetch league settings

```swift
let response = try await client.fetchLeagueSettings(leagueKey: "449.l.123456")
let settings = response.settings

print("Scoring: \(settings.scoringType ?? "?")")
print("Playoffs: \(settings.numPlayoffTeams ?? 0) teams from week \(settings.playoffStartWeek ?? 0)")

let starters = settings.rosterPositions
    .filter { !["BN", "IR"].contains($0.position) }
    .map { "\($0.count)×\($0.position)" }
    .joined(separator: " ")
print("Starting lineup: \(starters)")

// Join each scored stat to its point value on stat_id
let pointsByStatId = Dictionary(uniqueKeysWithValues: settings.statModifiers.map { ($0.statId, $0.value) })
for stat in settings.statCategories where stat.enabled {
    print("  \(stat.name): \(pointsByStatId[stat.statId].map(String.init) ?? "—")")
}
```

Returns `CDYahooLeagueSettingsResponse` (`leagueKey`, `settings: CDYahooLeagueSettings`).
`CDYahooLeagueSettings` carries the scoring type, the playoff/waiver/trade rules
(`usesPlayoff`, `playoffStartWeek`, `numPlayoffTeams`, `numPlayoffConsolationTeams`,
`usesPlayoffReseeding`, `waiverType`, `waiverRule`, `usesFaab`, `waiverTime`, `tradeEndDate`,
`tradeRatifyType`, `tradeRejectTime` — all optional), and three lists: `rosterPositions`
(`CDYahooRosterPosition`: `position`, `positionType?`, `count`), `statCategories`
(`CDYahooStatCategory`: `statId`, `name`, `displayName?`, `enabled`, `sortOrder?`,
`positionType?`), and `statModifiers` (`CDYahooStatModifier`: `statId`, `value`). Categories and
modifiers are parallel lists joined on `statId`.

### Fetch draft results

```swift
// Every pick in the league's draft
let league = try await client.fetchLeagueDraftResults(leagueKey: "449.l.123456")
for pick in league.draftResults {
    let bid = pick.cost.map { " ($\($0))" } ?? ""
    print("R\(pick.round) #\(pick.pick): \(pick.teamKey) → \(pick.playerKey)\(bid)")
}

// Just one team's picks
let team = try await client.fetchTeamDraftResults(teamKey: "449.l.123456.t.5")
print("\(team.teamKey) made \(team.draftResults.count) picks")
```

`fetchLeagueDraftResults(leagueKey:)` returns `CDYahooLeagueDraftResultsResponse` (`leagueKey`,
`draftResults: [CDYahooDraftResult]`); `fetchTeamDraftResults(teamKey:)` returns
`CDYahooTeamDraftResultsResponse` (`teamKey`, `draftResults`). Each `CDYahooDraftResult` carries
`pick`, `round`, `teamKey`, and `playerKey`, plus `cost` (`Int?`) — populated only for auction
drafts. Before a league drafts, `draftResults` is empty.

### Fetch team matchups and stats

```swift
// A team's head-to-head matchups. Omit `weeks` for the full schedule.
let matchups = try await client.fetchTeamMatchups(teamKey: "449.l.123456.t.5", weeks: [1, 2, 3])
for matchup in matchups.matchups {
    let scores = matchup.teams.map { "\($0.name) \($0.totalPoints ?? 0)" }.joined(separator: " vs ")
    let outcome = matchup.isTied == true ? "tie" : (matchup.winnerTeamKey ?? "pending")
    print("Week \(matchup.week): \(scores) — \(outcome)")
}

// A team's accumulated stats for a coverage window
let seasonStats = try await client.fetchTeamStats(teamKey: "449.l.123456.t.5")          // .season is the default
let week8Stats = try await client.fetchTeamStats(teamKey: "449.l.123456.t.5", coverage: .week(8))
print("Week 8 total: \(week8Stats.stats.totalPoints ?? 0)")
for stat in week8Stats.stats.stats {
    print("stat \(stat.statId) = \(stat.value)")
}
```

`fetchTeamMatchups(teamKey:weeks:)` returns `CDYahooTeamMatchupsResponse` (`teamKey`,
`matchups: [CDYahooMatchup]`). It reuses the same `CDYahooMatchup` / `CDYahooMatchupTeamScore`
types as [the scoreboard](#fetch-the-weekly-scoreboard), additionally populating `weekStart`,
`weekEnd`, `isPlayoffs`, `isConsolation`, `isTied`, `winnerTeamKey`, and each side's
`projectedPoints` (all `nil` in a scoreboard response). Pass `weeks:` to limit the result;
omit it (or pass `nil`) for the team's full schedule.

`fetchTeamStats(teamKey:coverage:)` returns `CDYahooTeamStatsResponse` (`teamKey`,
`stats: CDYahooTeamStats`). `coverage` is a `CDYahooTeamStatsCoverage` — `.season` (the default)
or `.week(Int)`. `CDYahooTeamStats` carries `coverageType`, `week`, `totalPoints` (the fantasy
points earned in the window), and `stats: [CDYahooTeamStat]`. Each `CDYahooTeamStat` has a
`statId` (join it to the league settings' `CDYahooStatCategory` / `CDYahooStatModifier`) and a
`value` kept as a `String` — Yahoo emits `-` for a stat with no value in the window.

### Fetch game metadata

The four `game/{game_key}` sub-resources describe a fantasy game's rules — the same rules a
league configures a subset of. `gameKey` is a Yahoo game key or game code (`"449"` or `"nfl"`);
get one from [the user's games](#fetch-the-users-games-and-leagues).

```swift
let statCategories = try await client.fetchGameStatCategories(gameKey: "nfl")
for stat in statCategories.statCategories {
    print("\(stat.statId): \(stat.name) — applies to \(stat.statPositionTypes)")
}

let positionTypes = try await client.fetchGamePositionTypes(gameKey: "nfl")
for type in positionTypes.positionTypes {
    print("\(type.type) = \(type.displayName ?? "")")
}

let rosterPositions = try await client.fetchGameRosterPositions(gameKey: "nfl")
for position in rosterPositions.rosterPositions {
    print("\(position.position) (\(position.positionType ?? "—")): \(position.displayName ?? "")")
}

let gameWeeks = try await client.fetchGameWeeks(gameKey: "nfl")
for week in gameWeeks.gameWeeks {
    print("Week \(week.week): \(week.start ?? "?") – \(week.end ?? "?")")
}
```

- `fetchGameStatCategories(gameKey:)` → `CDYahooGameStatCategoriesResponse` (`gameKey`,
  `statCategories: [CDYahooGameStatCategory]`). Each `CDYahooGameStatCategory` has `statId`,
  `name`, `displayName`, `sortOrder`, `positionType`, and `statPositionTypes: [String]`. Unlike
  the league-scoped `CDYahooStatCategory` it has no `enabled` flag — that is a per-league setting.
- `fetchGamePositionTypes(gameKey:)` → `CDYahooGamePositionTypesResponse` (`gameKey`,
  `positionTypes: [CDYahooPositionType]`). Each `CDYahooPositionType` has `type` and `displayName`.
- `fetchGameRosterPositions(gameKey:)` → `CDYahooGameRosterPositionsResponse` (`gameKey`,
  `rosterPositions: [CDYahooGameRosterPosition]`). Each `CDYahooGameRosterPosition` has
  `position`, `abbreviation`, `displayName`, and `positionType`. Distinct from the league-scoped
  `CDYahooRosterPosition`, which instead carries the `count` a league starts.
- `fetchGameWeeks(gameKey:)` → `CDYahooGameWeeksResponse` (`gameKey`,
  `gameWeeks: [CDYahooGameWeek]`). Each `CDYahooGameWeek` has `week`, `displayName`, `start`, and
  `end` (`YYYY-MM-DD`).

---

## Error Handling

Every method throws `CDYahooKitError`. Wrap calls in `do` / `catch`:

```swift
do {
    let standings = try await client.fetchLeagueStandings(leagueKey: leagueKey)
    // …
} catch let error as CDYahooKitError {
    switch error {
    case .invalidCredentials(let message):
        // No/expired refresh token, OAuth state mismatch, empty credentials.
        // Re-run the sign-in flow.
        print("Auth problem: \(message)")
    case .apiError(let description):
        // Yahoo's <error> envelope — an invalid key, a private league, a revoked grant.
        print("Yahoo says: \(description)")
    case .invalidRequest(let underlying):
        print("Could not build/complete the request: \(underlying.localizedDescription)")
    case .xmlParsingFailed(let underlying):
        print("Response was not valid XML: \(underlying.localizedDescription)")
    case .responseDecodingFailed(let underlying):
        print("Unexpected response shape: \(underlying.localizedDescription)")
    case .authorizationCancelled:
        print("User cancelled sign-in.")
    }
} catch {
    print("Unexpected: \(error)")
}
```

| Case | Typical cause |
|------|---------------|
| `invalidCredentials(String)` | No refresh token stored, `invalid_grant` from Yahoo, OAuth `state` mismatch, or empty client credentials. |
| `invalidRequest(underlying:)` | A malformed route value, or a non-2xx HTTP response with no recognizable `<error>` body. |
| `xmlParsingFailed(underlying:)` | `XMLParser` failed on the response body. |
| `responseDecodingFailed(underlying:)` | XML parsed, but a required field was missing or the OAuth JSON didn't decode. |
| `apiError(String)` | Yahoo returned its `<error><description>…</description></error>` envelope. The string is the `<description>`. |
| `authorizationCancelled` | The user dismissed the `ASWebAuthenticationSession` sheet. |

`CDYahooKitError` conforms to `LocalizedError`, so `error.localizedDescription` is
presentable. Empty client credentials trip a `precondition` at `init` (a programmer error),
not a thrown error.

---

## Configuration

All four pipeline layers are opt-in on `CDYahooFantasyAPIClient.init` and apply to the
Fantasy Sports data requests only — OAuth token exchange and refresh stay unlayered by
design.

### Retry

```swift
let client = CDYahooFantasyAPIClient(
    clientId: …, clientSecret: …, redirectUrl: …,
    retryConfiguration: .enabled(maximumRetryCount: 3, baseDelay: 0.5)
)
```

`CDYahooRetryConfiguration` — `.disabled` (default) or
`.enabled(maximumRetryCount:baseDelay:)`. Retries only **transient** failures: transport
errors with no HTTP response, HTTP `429`, and HTTP `5xx`. A `4xx`, Yahoo's `<error>`
envelope, and an undecodable body are never retried. Backoff is
`baseDelay * 2^(attempt - 1)`; cancelling the wrapping `Task` interrupts a pending backoff.

### Response cache

```swift
cacheConfiguration: .enabled(maximumEntries: 100, timeToLive: 300)
```

`CDYahooCacheConfiguration` — `.disabled` (default) or
`.enabled(maximumEntries:timeToLive:)`. Caches successful `GET` response bodies in memory
for `timeToLive` seconds. The cache key includes the `Authorization` header, so entries are
automatically scoped to the current token (a different signed-in user, or a refreshed token,
never sees a stale entry). At `maximumEntries` the cache clears wholesale. A cache hit skips
the network **and** the event monitors.

### Request adapters

```swift
struct TracingAdapter: CDYahooRequestAdapter {
    func adapt(_ request: URLRequest) -> URLRequest {
        var request = request
        request.setValue(UUID().uuidString, forHTTPHeaderField: "X-Trace-Id")
        return request
    }
}

let client = CDYahooFantasyAPIClient(
    clientId: …, clientSecret: …, redirectUrl: …,
    requestAdapters: [TracingAdapter()]
)
```

Adapters run in the order supplied, once per logical call before the first attempt (not per
retry). The cache key is computed from the adapted request.

### Event monitors

```swift
struct LoggingMonitor: CDYahooEventMonitor {
    func willSend(_ request: URLRequest) {
        print("→ \(request.httpMethod ?? "GET") \(request.url?.path ?? "")")
    }
    func didReceive(_ response: URLResponse?, data: Data?, error: (any Error)?) {
        if let error { print("✗ \(error.localizedDescription)") }
        else if let http = response as? HTTPURLResponse { print("← \(http.statusCode)") }
    }
}

let client = CDYahooFantasyAPIClient(
    clientId: …, clientSecret: …, redirectUrl: …,
    eventMonitors: [LoggingMonitor()]
)
```

Read-only. `willSend` fires before every attempt; `didReceive` fires on every response and
on every thrown error.

---

## Cancellation

Cancel the `Task` wrapping a fetch call:

```swift
let task = Task {
    do {
        let standings = try await client.fetchLeagueStandings(leagueKey: leagueKey)
        render(standings)
    } catch is CancellationError {
        // expected on cancel
    } catch {
        showError(error)
    }
}

// later
task.cancel()
```

The in-flight `URLSessionTask` is cancelled by the runtime, and a pending retry backoff
throws `CancellationError` rather than continuing.

---

## Testing Utilities

The `CDYahooKitTesting` product exposes `CDYahooMockURLProtocol`, a `URLProtocol` that
intercepts requests and returns a pre-configured response so your own tests never hit
Yahoo.

```swift
import Testing
import CDYahooKit
import CDYahooKitTesting

@Suite("League standings")
struct LeagueStandingsTests {
    @Test
    func parsesRankedTeams() async throws {
        let session = CDYahooMockURLProtocol.makeSession()
        let client = CDYahooFantasyAPIClient(
            clientId: "test", clientSecret: "test", redirectUrl: "test://cb",
            urlSession: session
        )

        let xml = """
        <?xml version="1.0"?>
        <fantasy_content><league><league_key>449.l.1</league_key><standings><teams>
          <team><team_key>449.l.1.t.1</team_key><team_id>1</team_id><name>Alpha</name>
            <team_standings><rank>1</rank></team_standings></team>
        </teams></standings></league></fantasy_content>
        """

        let url = URL(string: "https://fantasysports.yahooapis.com/fantasy/v2/league/449.l.1/standings")!
        CDYahooMockURLProtocol.register(
            stub: .init(statusCode: 200, data: Data(xml.utf8)),
            for: url
        )

        // Skip the OAuth round-trip by pre-seeding a token, or stub the token URL too.
        let response = try await client.fetchLeagueStandings(leagueKey: "449.l.1")
        #expect(response.teams.first?.name == "Alpha")
    }
}
```

`Stub` also accepts `headers`, `error`, and `delay`. Attach stubs two ways:

- `register(stub:for:)` / `register(stubs:for:)` — keyed by exact `URL`, for code that
  builds its own request (every `CDYahooFantasyAPIClient` fetch method). A queue of stubs
  for one URL lets you exercise the retry loop; `requestCount(for:)` reports how many
  attempts were made. Give each test a distinct URL so concurrent tests don't collide.
- `stubbing(_:with:)` — attaches a stub to one specific `URLRequest` instance.

Because `CDYahooFantasyAPIClient` forwards its `urlSession:` to the OAuth client too, one
mock session covers both token and data traffic.

> The XML fixtures under `Tests/CDYahooKitTests/Fixtures/` are hand-authored and not yet
> verified against a live Yahoo account — see [ARCHITECTURE.md](ARCHITECTURE.md#testing-architecture).

---

## Platform Notes

- **tvOS / watchOS** — no `CDYahooAuthSession`. Use the
  [out-of-band flow](#out-of-band-sign-in-tvos--watchos). All data methods work normally
  once a token is stored.
- **Keychain is per-device** — a token stored on iOS does not appear on a paired watch.
  Sharing would require a Keychain access group, which this library doesn't configure.
- **`@MainActor`** — `CDYahooFantasyAPIClient` methods must be called from the main actor or
  a `Task`; the `CDYahooOAuthClient` is an `actor`, so its members are `await`-ed.

---

## How to Contribute

To add a Fantasy Sports resource:

1. Add a `CDYahooRouter` case that builds the `fantasy/v2/…` path.
2. Add the response model(s) with `init(node:)` conforming to `CDYahooXMLDecodable`.
3. Add a `public func fetch…(…) async throws -> …Response` on `CDYahooFantasyAPIClient` that
   goes through `authorizedRequest(_:)` → `session.perform(_:)`.
4. Add an XML fixture and a Swift Testing suite under `Tests/CDYahooKitTests/`.
5. If the file must build in the native Xcode targets, add it to
   `CDYahooKit.xcodeproj/project.pbxproj` for each platform target.
6. Add `///` docs and a `- ``Symbol``` line under the right `## Topics` section in
   `Source/CDYahooKit.docc/CDYahooKit.md`.
7. `swiftformat Source Tests && swiftlint lint --strict && swift test`.

See [CONTRIBUTING.md](../CONTRIBUTING.md) for the full workflow.

---

## Further Reading

- [ARCHITECTURE.md](ARCHITECTURE.md) — request lifecycle, OAuth flow, XML engine, concurrency
- [Yahoo Fantasy Sports API guide](https://developer.yahoo.com/fantasysports/guide/)
- [OAuth 2.0 for Yahoo](https://developer.yahoo.com/oauth2/guide/)
- [Full API reference](https://chrisdhaan.github.io/CDYahooKit/documentation/cdyahookit/)
