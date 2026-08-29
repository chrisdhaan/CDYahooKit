# CDYahooKit Architecture

## System Overview

CDYahooKit is a pure-Swift, zero-runtime-dependency wrapper for the **Yahoo Fantasy Sports
API**, with **Sign In With Yahoo** (OAuth 2.0 authorization-code flow + PKCE) for
authentication. It handles four things:

1. The OAuth 2.0 / PKCE handshake and silent token refresh (`CDYahooOAuthClient`,
   `CDYahooAuthSession`, `CDYahooPKCE`).
2. Keychain persistence of the resulting access / refresh tokens
   (`CDYahooKeychain`).
3. Authenticated `GET` requests against the Fantasy Sports API through a native
   `URLSession`-backed pipeline with opt-in cache / retry / adapter / monitor layers
   (`CDYahooFantasyAPIClient`, `CDYahooRouter`, `CDYahooURLSession`).
4. Parsing the API's **XML** responses into strongly-typed Swift `struct`s via one shared
   XML tree engine (`CDYahooXMLTreeBuilder` → `CDYahooXMLNode` → each model's
   `init(node:)`).

The only external dependency in `Package.swift` is `swift-docc-plugin`, used to build the
documentation site — nothing ships in the library binary but Foundation, Security /
CryptoKit, and (where available) AuthenticationServices.

```
CDYahooFantasyAPIClient (@MainActor, public API)
  ├─ CDYahooOAuthClient          — OAuth 2.0 + PKCE; validAccessToken() refreshes silently; Keychain-backed  (an actor)
  │     ├─ CDYahooOAuthRouter    — authorize / refresh → URLRequest against api.login.yahoo.com/oauth2
  │     ├─ CDYahooOAuthCredential — Codable decode of the token endpoint's JSON body
  │     ├─ CDYahooPKCE           — S256 code verifier / challenge
  │     ├─ CDYahooKeychain       — generic-password SecItem storage, AfterFirstUnlockThisDeviceOnly
  │     └─ CDYahooAuthSession    — ASWebAuthenticationSession async/await wrapper (iOS / macOS / visionOS)
  ├─ CDYahooRouter               — endpoint enum case → URLRequest against fantasy/v2/*
  └─ CDYahooURLSession
        ├─ applies request adapters, event monitors, retry, and the GET response cache
        ├─ CDYahooXMLTreeBuilder → CDYahooXMLNode tree
        └─ hands the root node to the response type's init(node:) (CDYahooXMLDecodable)
```

---

## Key Components

### CDYahooFantasyAPIClient

The primary public interface — a `@MainActor public final class`. All state mutation happens
on the main actor, so the class needs no explicit `Sendable` conformance in Swift 6 (actor
isolation already provides the guarantee).

Responsibilities:

- Owns a `CDYahooURLSession` (private) for performing Fantasy Sports requests, and a
  `CDYahooOAuthClient` (public, exposed as `oAuthClient` so callers can drive the sign-in
  flow and check `isAuthorized()`).
- Exposes one `public func fetch…(…) async throws -> …Response` per routed endpoint (ten
  in v1).
- `authorizedRequest(_:)` is the single private choke point every fetch method goes through:
  it calls `oAuthClient.validAccessToken()` (which refreshes silently if needed), then
  `route.asURLRequest(accessToken:)`.

```swift
public init(clientId: String, clientSecret: String, redirectUrl: String,
            urlSession: URLSession = URLSession(configuration: .default),
            retryConfiguration: CDYahooRetryConfiguration = .disabled,
            eventMonitors: [any CDYahooEventMonitor] = [],
            requestAdapters: [any CDYahooRequestAdapter] = [],
            cacheConfiguration: CDYahooCacheConfiguration = .disabled)
```

The `urlSession` is shared with the `CDYahooOAuthClient` (so a `CDYahooMockURLProtocol`
session stubs both data and token traffic), but the retry / monitor / adapter / cache
configuration is applied **only** to the Fantasy Sports pipeline — OAuth token requests
stay deliberately plain (see [OAuth token requests are unlayered](#oauth-token-requests-are-unlayered)).

### CDYahooOAuthClient

Manages the OAuth credential lifecycle. Declared `public actor` rather than a `Sendable`
class. The actor isolation is load-bearing, not stylistic:

> Yahoo **rotates the refresh token on every use**. If two concurrent callers of
> `validAccessToken()` both saw an expired access token and each fired its own refresh, they
> would race to consume the same refresh token and the loser would come back with
> `invalid_grant`. Actor isolation, plus a cached in-flight `refreshTask`, funnels every
> concurrent caller onto the *same* single refresh.

Public surface:

| Member | Purpose |
|--------|---------|
| `init(clientId:clientSecret:redirectUrl:urlSession:)` | `precondition`s that all three credentials are non-empty. |
| `authorizationURL(codeChallenge:state:scope:)` | Builds the `request_auth` URL to hand to `ASWebAuthenticationSession`. `scope` is omitted when `nil` (keeps the app's default grant); pass e.g. `"openid fspt-r"` to also request Sign In With Yahoo identity. |
| `authorize(withCode:codeVerifier:)` | Exchanges the callback's authorization `code` + the PKCE `codeVerifier` for a token pair and stores it. |
| `isAuthorized()` | Synchronous, non-networking "should I show a Sign In button?" check — `true` if the access token is unexpired *or* a refresh token is stored. |
| `validAccessToken()` | Returns a currently-valid access token, silently refreshing first if it has expired. Throws `.invalidCredentials` if no refresh token is stored. |
| `unauthorize()` | Deletes the access token, refresh token, and expiry from the Keychain. |

Internals worth knowing:

- **Early-refresh margin.** On store, the expiry timestamp is `now + expires_in - 60`, so a
  token that is seconds from expiring at request time is refreshed rather than sent and
  rejected.
- **Dead-refresh-token cleanup.** `performTokenRequest` decodes the token endpoint's error
  body; on `invalid_grant` it calls `unauthorize()` before throwing, so `isAuthorized()`
  stops returning `true` for a session that can never be refreshed, and the app knows to
  re-run the web flow instead of retrying a dead token forever.

### CDYahooOAuthRouter

An enum with two cases — `authorize(code:redirectUrl:codeVerifier:)` and
`refresh(refreshToken:redirectUrl:)` — each of which builds a `POST` to
`https://api.login.yahoo.com/oauth2/get_token`:

- `Content-Type: application/x-www-form-urlencoded`
- `Authorization: Basic base64(clientId:clientSecret)` — HTTP Basic client authentication,
  not client credentials in the body
- Body is `grant_type` + `redirect_uri` + either `code` / `code_verifier` or
  `refresh_token`, percent-encoded with `+`, `&`, and `=` explicitly removed from the
  allowed set so they can't corrupt the form encoding.

### CDYahooOAuthCredential

`struct … : Codable, Sendable` decoding the token endpoint's **JSON** body (the OAuth
endpoint is JSON; only the Fantasy Sports data API is XML). Explicit snake_case
`CodingKeys`: `access_token`, `refresh_token?`, `expires_in`, `token_type`,
`xoauth_yahoo_guid?`. Internal — never returned to callers.

### CDYahooPKCE

`public enum` with two static functions, implementing RFC 7636 S256:

- `makeCodeVerifier()` — 32 cryptographically-random bytes (`SecRandomCopyBytes`),
  base64url-encoded to a 43-character string (within RFC 7636's 43–128 range). `precondition`s
  on RNG success — a non-random verifier would be a security defect, not a recoverable error.
- `codeChallenge(for:)` — `base64url(SHA256(verifier))` via CryptoKit.

### CDYahooKeychain

An internal `enum` (namespace, no instances) wrapping Keychain Services
(`SecItemAdd` / `SecItemCopyMatching` / `SecItemUpdate` / `SecItemDelete`). All three token
values are stored as `kSecClassGenericPassword` items under a fixed service name
(`"CDYahooKit"`) so they can't collide with another framework's Keychain use in the same
app. Accessibility is `kSecAttrAccessibleAfterFirstUnlockThisDeviceOnly`:

- **`AfterFirstUnlock`**, not `WhenUnlocked`, so a background token refresh isn't blocked on
  a locked device.
- **`ThisDeviceOnly`**, so tokens never migrate to another device via encrypted backup /
  restore.

`CDYahooDefaults` holds the three account keys (`CDYahooKit.accessToken`,
`CDYahooKit.refreshToken`, `CDYahooKit.tokenExpiry`).

### CDYahooAuthSession

An `async`/`await` wrapper around `ASWebAuthenticationSession` for the browser-redirect step
of the authorization-code flow. The whole file is behind
`#if os(iOS) || os(macOS) || os(visionOS)` — `ASWebAuthenticationSession` does not exist on
watchOS, and on tvOS is gated to tvOS 16+ while this package targets tvOS 15, so an
`@available` annotation alone wouldn't keep the type checker from resolving the signatures.

- `init(presentationAnchor:)` — takes an `@autoclosure @escaping` anchor provider.
- `authorize(authorizationURL:callbackScheme:) async throws -> URL` — presents the session,
  resumes with the callback URL. A user cancel is mapped to
  `CDYahooKitError.authorizationCancelled`.
- `static extractCode(from:expectedState:)` — verifies the callback's `state` query item
  matches the value you generated (CSRF guard) *before* returning the `code`; a mismatch or
  a missing code throws `.invalidCredentials`.

Modeled deliberately on CDOAuth1Kit's `CDOAuth1AuthSession` — same
`ASWebAuthenticationPresentationContextProviding` shape, same "retain the in-flight session"
property. The functional difference is only what comes back in the callback: an OAuth 1.0a
`oauth_verifier` there, an OAuth 2.0 `code` (+ `state`) here.

### CDYahooRouter

An enum where each case is one Fantasy Sports endpoint and `asURLRequest(accessToken:)`
turns it into a `GET` `URLRequest` against
`https://fantasysports.yahooapis.com/fantasy/v2/`, with
`Authorization: Bearer {token}` and `Accept: application/xml`.

| Case | Path (relative to `fantasy/v2/`) |
|------|----------------------------------|
| `userGames(gameCode:)` | `users;use_login=1/games;game_codes={code}/leagues` |
| `league(leagueKey:)` | `league/{leagueKey}` |
| `standings(leagueKey:)` | `league/{leagueKey}/standings` |
| `roster(teamKey:week:)` | `team/{teamKey}/roster` — `;week={week}` appended when `week != nil` |
| `players(leagueKey:start:)` | `league/{leagueKey}/players` — `;start={start}` appended when `start != nil` |
| `scoreboard(leagueKey:week:)` | `league/{leagueKey}/scoreboard` — `;week={week}` appended when `week != nil` |
| `transactions(leagueKey:)` | `league/{leagueKey}/transactions` |
| `settings(leagueKey:)` | `league/{leagueKey}/settings` |
| `leagueDraftResults(leagueKey:)` | `league/{leagueKey}/draftresults` |
| `teamDraftResults(teamKey:)` | `team/{teamKey}/draftresults` |
| `teamMatchups(teamKey:weeks:)` | `team/{teamKey}/matchups` — `;weeks={w1},{w2},…` appended when `weeks` is non-empty |
| `teamStats(teamKey:coverage:)` | `team/{teamKey}/stats;type=season` or `…;type=week;week={week}` |
| `gameStatCategories(gameKey:)` | `game/{gameKey}/stat_categories` |
| `gamePositionTypes(gameKey:)` | `game/{gameKey}/position_types` |
| `gameRosterPositions(gameKey:)` | `game/{gameKey}/roster_positions` |
| `gameWeeks(gameKey:)` | `game/{gameKey}/game_weeks` |

League / team / game keys are percent-encoded before interpolation (allowed set:
alphanumerics + `-._~`), so a value carrying `?`, `#`, or `/` can't silently reshape the URL
onto a different route — it either encodes cleanly or the request fails.

### CDYahooURLSession

An internal `final class … : Sendable` — all five stored properties are immutable, and the
GET cache is its own `actor`, so no manual locking is needed. `perform(_:)` is the request
pipeline; see [Request Lifecycle](#request-lifecycle).

### XML engine (`CDYahooXMLTreeBuilder` / `CDYahooXMLNode` / `CDYahooXMLDecodable`)

The Fantasy Sports API is XML-native. Rather than a bespoke `XMLParser` delegate per
response type, CDYahooKit parses each response **once** into an in-memory tree and each model
reads from that tree:

- `CDYahooXMLTreeBuilder` — the only `XMLParserDelegate` in the library. `static parse(_:)`
  runs a single stack-based pass and returns the root `CDYahooXMLNode`, or throws
  `CDYahooKitError.xmlParsingFailed`.
- `CDYahooXMLNode` — `struct` with `name` / `attributes` / `children` / `text` and
  traversal helpers: `child(_:)`, `children(_:)`, `text(_:)` (trimmed text of a named child,
  `nil` for missing / self-closing / empty — Yahoo uses all three for "no value"), and
  `int(_:)`.
- `CDYahooXMLDecodable` — `protocol { init(node:) throws }`. The XML analog of `Decodable`.
  Every response and nested model conforms.
- `CDYahooXMLDecodingError` — thrown by `init(node:)` when a required field is missing,
  carrying the field name.

---

## Request Lifecycle

```
Caller (main actor or a Task)
  │
  ▼
CDYahooFantasyAPIClient.fetchLeagueStandings(leagueKey:)          ← @MainActor
  │
  ├── authorizedRequest(.standings(leagueKey:))
  │       ├── oAuthClient.validAccessToken()                       ← actor; silent refresh if expired
  │       └── CDYahooRouter.standings.asURLRequest(accessToken:)   ← GET + Bearer + Accept: application/xml
  │
  ▼
CDYahooURLSession.perform(request) -> CDYahooLeagueStandingsResponse
  │
  ├── 1. requestAdapters.reduce(request) { $0.adapt($1) }          ← run once, before attempt 1 (not per retry)
  │
  ├── 2. cacheable? (httpMethod == nil || "GET")
  │      cacheKey = "\(url)|\(Authorization header)"
  │      cache hit → decode cached Data, return                    ← no network, no monitors
  │
  ├── 3. retry loop (attempt = 0):
  │        eventMonitors.willSend(request)
  │        attemptOnce(request):
  │          session.data(for: request)
  │          eventMonitors.didReceive(response, data, nil)
  │          non-2xx → attemptFailure(forNon2xxResponse:)          ← parse <error> body → .apiError
  │          2xx → cache.store(data) if cacheable
  │               CDYahooXMLTreeBuilder.parse(data)
  │               root.name == "error" → throw .apiError
  │               else → T(node: root)                             ← CDYahooLeagueStandingsResponse.init(node:)
  │        on throw:
  │          (thrown, isTransient) = unwrap(error)
  │          eventMonitors.didReceive(nil, nil, thrown)
  │          retry iff isTransient && ++attempt <= maximumRetryCount
  │          sleep baseDelay * 2^(attempt-1), then loop
  │
  ▼
CDYahooLeagueStandingsResponse                                     ← returned to caller
```

### Adapter chain

`requestAdapters: [any CDYahooRequestAdapter]` (default `[]`). Each adapter's
`adapt(_:) -> URLRequest` runs in supplied order, **once per logical call before the first
attempt** — not once per retry. Use it for cross-cutting request mutation (custom headers,
tracing IDs). The cache key is computed from the *adapted* request.

### GET response cache

`cacheConfiguration: CDYahooCacheConfiguration` (default `.disabled`). When enabled
(`.enabled(maximumEntries: 100, timeToLive: 300)` by default), successful `GET` response
bodies are held in an in-memory `actor` (`CDYahooResponseCache`) for `timeToLive` seconds.

- The **cache key includes the `Authorization` header value**, so an entry is automatically
  invalidated when a different access token is in play (a different signed-in user, or a
  silently-refreshed token) with no explicit coordination between the cache and the OAuth
  client.
- Only the raw response `Data` is cached, and only after a successful HTTP status — decoding
  happens fresh on every hit.
- At `maximumEntries` the cache clears wholesale rather than evicting LRU — simple, and the
  entries are small and short-lived.
- A hit **skips `eventMonitors` entirely** (no `willSend` / `didReceive` pair), unlike some
  sibling frameworks.

### Retry

`retryConfiguration: CDYahooRetryConfiguration` (default `.disabled`;
`.enabled(maximumRetryCount: 3, baseDelay: 0.5)` for exponential backoff). What is
**transient** (retried):

- A transport-level error straight out of `session.data(for:)` (no HTTP response at all).
- HTTP `429` or any `5xx`.

What is **not** transient (surfaced immediately):

- Any other `4xx`.
- Yahoo's `<error>` envelope (it's a definitive answer — retrying won't change it).
- A malformed / undecodable response body.

Backoff sleep uses `try await Task.sleep` (not `try?`), so cancelling the wrapping `Task`
propagates `CancellationError` instead of letting the remaining retries fire back-to-back.

### Event monitors

`eventMonitors: [any CDYahooEventMonitor]` (default `[]`). `willSend(_:)` fires before each
attempt; `didReceive(_:data:error:)` fires on every response and on every thrown error
(with `nil` response / data). Read-only — for logging, metrics, breadcrumbs.

### OAuth token requests are unlayered

`CDYahooOAuthClient.performTokenRequest` calls `session.data(for:)` directly. Token exchange
and refresh get **no** retry, cache, adapters, or monitors — they're infrequent, must not be
retried blindly (a rotated refresh token is single-use), and must never be cached. Only the
Fantasy Sports data pipeline is layered.

---

## OAuth 2.0 + PKCE Flow

```
                    ┌─────────────────────────── your app ───────────────────────────┐
                    │                                                                │
 CDYahooPKCE.makeCodeVerifier() ───► verifier ──► CDYahooPKCE.codeChallenge(for:) ──► challenge
                    │                                                                │
 state = UUID().uuidString                                                           │
                    │                                                                │
 oAuthClient.authorizationURL(codeChallenge: challenge, state: state) ──► authURL    │
                    │                                                                │
 CDYahooAuthSession(presentationAnchor:).authorize(authorizationURL: authURL,        │
                                                   callbackScheme: "myapp") ──► ASWebAuthenticationSession
                    │                                                          (user signs in at Yahoo,
                    │                                                           approves the scope)
                    ▼                                                                │
        callback URL: myapp://callback?code=…&state=…                                │
                    │                                                                │
 CDYahooAuthSession.extractCode(from: callback, expectedState: state) ──► code       │
       (throws .invalidCredentials on state mismatch — CSRF guard)                   │
                    │                                                                │
 oAuthClient.authorize(withCode: code, codeVerifier: verifier)                       │
                    │   POST /oauth2/get_token  (grant_type=authorization_code)      │
                    ▼                                                                │
        { access_token, refresh_token, expires_in, … }  ──►  Keychain                │
                    │                                                                │
                    └───────────────────────── later ────────────────────────────────┘
                                                │
 any fetch…() ──► oAuthClient.validAccessToken()
                    │
                    ├─ access token unexpired?  ─► return it
                    │
                    └─ expired:
                         refreshTask already in flight?  ─► await the same one
                         else: POST /oauth2/get_token (grant_type=refresh_token)
                               store new pair (Yahoo rotates the refresh token)
                               return new access token
                         no refresh token stored?  ─► throw .invalidCredentials
                                                       (caller must re-run the web flow)
```

**tvOS / watchOS** have no `CDYahooAuthSession`. The app builds `authURL` from
`oAuthClient.authorizationURL(…)`, completes the browser step out of band (a companion
device, a paired phone, a server-side exchange), and calls
`oAuthClient.authorize(withCode:codeVerifier:)` with the code it obtained. Everything after
that — `validAccessToken()`, silent refresh, all ten fetch methods — works identically on
all five platforms.

---

## Keychain Storage

Three generic-password items under service `"CDYahooKit"`:

| Account key | Value |
|-------------|-------|
| `CDYahooKit.accessToken` | Bearer token for Fantasy Sports requests |
| `CDYahooKit.refreshToken` | Single-use refresh token (rotated on every use) |
| `CDYahooKit.tokenExpiry` | `timeIntervalSince1970` of `now + expires_in - 60`, as a string |

`set(_:forKey:)` tries `SecItemUpdate` first and falls back to `SecItemAdd` on
`errSecItemNotFound`, so re-authorizing overwrites rather than duplicating. `unauthorize()`
deletes all three; a delete of a missing item is treated as success.

The Keychain is **not** shared between an iOS app and its paired watchOS app by default —
that needs a Keychain access group via the `com.apple.security.application-groups`
entitlement, which this library does not configure. Signing in on iOS will not make
`isAuthorized()` return `true` on the watch.

---

## XML Parsing Engine

### Why XML, not `format=json`

The Fantasy Sports API is XML-native. Its `format=json` parameter exists but produces
**inconsistent shapes** — a single item and a one-element collection serialize differently
depending on cardinality — and any future write request must be XML regardless of the read
format. CDYahooKit treats XML as the source of truth end to end.

### Why a shared tree, not a delegate per type

A hand-rolled `XMLParser` delegate per response would mean re-implementing element-stack
bookkeeping, character buffering, and whitespace trimming a dozen-plus times. Instead:

1. `CDYahooXMLTreeBuilder.parse(data)` walks the document once, pushing a `CDYahooXMLNode`
   on `didStartElement`, appending trimmed text on `foundCharacters`, and popping into the
   parent's `children` on `didEndElement`. Result: one `CDYahooXMLNode` root.
2. Each model's `init(node:) throws` reads what it needs with `child` / `children` / `text` /
   `int`, throwing `CDYahooXMLDecodingError.missingField` when a required element is absent.

### The `<error>` envelope

Yahoo returns an `<error><description>…</description></error>` document **with a non-2xx
status code** on failure. `CDYahooURLSession` handles this in two places so it can never slip
through as a decode failure:

- `attemptFailure(forNon2xxResponse:)` parses the body of any non-2xx response; if the root
  element is `error`, it surfaces `CDYahooKitError.apiError(description)` (non-transient).
- `decode(_:)` re-checks the root element name even on a 2xx response and throws
  `.apiError` rather than handing an `<error>` tree to a model's `init(node:)`.

---

## Response Model Hierarchy

Every `fetch…` method returns a dedicated `…Response` `struct`. All models — responses and
their nested types — are `struct`, and conform to
`CDYahooXMLDecodable, Sendable, Equatable, Codable`, with a `public` memberwise initializer
(for tests and previews) alongside the internal `init(node:)`.

```
CDYahooUserGamesResponse                 ← users;use_login=1/games;game_codes={code}/leagues
  └── [CDYahooGame]                        gameKey, gameId, name, code, season
        └── [CDYahooLeagueSummary]         leagueKey, leagueId, name, numTeams?

CDYahooLeagueResponse                    ← league/{leagueKey}
  └── CDYahooLeague                        leagueKey, leagueId, name, url?, numTeams?,
                                           scoringType?, currentWeek?, season?

CDYahooLeagueStandingsResponse          ← league/{leagueKey}/standings
  ├── leagueKey
  └── [CDYahooTeamStanding]               teamKey, teamId, name, rank?, pointsFor?, pointsAgainst?
        └── CDYahooTeamOutcomeTotals?     wins, losses, ties, percentage

CDYahooTeamRosterResponse               ← team/{teamKey}/roster[;week={week}]
  ├── teamKey, name
  └── [CDYahooPlayer]                     playerKey, playerId, fullName, editorialTeamAbbr?,
                                           displayPosition?, selectedPosition?, status?

CDYahooLeaguePlayersResponse            ← league/{leagueKey}/players[;start={start}]
  ├── leagueKey
  └── [CDYahooPlayer]                     ← same CDYahooPlayer type as the roster response

CDYahooLeagueScoreboardResponse         ← league/{leagueKey}/scoreboard[;week={week}]
  ├── leagueKey
  └── [CDYahooMatchup]                    week, status, weekStart?, weekEnd?, isPlayoffs?,
        │                                  isConsolation?, isTied?, winnerTeamKey?
        └── [CDYahooMatchupTeamScore]     teamKey, name, totalPoints?, projectedPoints?

CDYahooLeagueTransactionsResponse       ← league/{leagueKey}/transactions
  ├── leagueKey
  └── [CDYahooTransaction]                transactionKey, transactionId, type, status
        └── [CDYahooTransactionPlayer]    playerKey, fullName, transactionType?, destinationTeamKey?

CDYahooLeagueSettingsResponse          ← league/{leagueKey}/settings
  ├── leagueKey
  └── CDYahooLeagueSettings               scoringType?, usesPlayoff?, playoffStartWeek?, numPlayoffTeams?,
        │                                  numPlayoffConsolationTeams?, usesPlayoffReseeding?, waiverType?,
        │                                  waiverRule?, usesFaab?, waiverTime?, tradeEndDate?,
        │                                  tradeRatifyType?, tradeRejectTime?
        ├── [CDYahooRosterPosition]        position, positionType?, count
        ├── [CDYahooStatCategory]          statId, name, displayName?, enabled, sortOrder?, positionType?
        └── [CDYahooStatModifier]          statId, value        (joins to CDYahooStatCategory on statId)

CDYahooLeagueDraftResultsResponse     ← league/{leagueKey}/draftresults
  ├── leagueKey
  └── [CDYahooDraftResult]               pick, round, cost?, teamKey, playerKey

CDYahooTeamDraftResultsResponse       ← team/{teamKey}/draftresults
  ├── teamKey
  └── [CDYahooDraftResult]               same CDYahooDraftResult type as the league response

CDYahooTeamMatchupsResponse          ← team/{teamKey}/matchups[;weeks={w1},{w2},…]
  ├── teamKey
  └── [CDYahooMatchup]                   same CDYahooMatchup type as the scoreboard response

CDYahooTeamStatsResponse             ← team/{teamKey}/stats;type=season | …;type=week;week={week}
  ├── teamKey
  └── CDYahooTeamStats                   coverageType?, week?, totalPoints?
        └── [CDYahooTeamStat]            statId, value        (joins to CDYahooStatCategory on statId)

CDYahooGameStatCategoriesResponse    ← game/{gameKey}/stat_categories
  ├── gameKey
  └── [CDYahooGameStatCategory]          statId, name, displayName?, sortOrder?, positionType?,
                                          statPositionTypes

CDYahooGamePositionTypesResponse    ← game/{gameKey}/position_types
  ├── gameKey
  └── [CDYahooPositionType]              type, displayName?

CDYahooGameRosterPositionsResponse  ← game/{gameKey}/roster_positions
  ├── gameKey
  └── [CDYahooGameRosterPosition]        position, abbreviation?, displayName?, positionType?

CDYahooGameWeeksResponse            ← game/{gameKey}/game_weeks
  ├── gameKey
  └── [CDYahooGameWeek]                  week, displayName?, start?, end?
```

Optionality mirrors the API: a field the API always returns (keys, names) is non-optional
and its absence throws `missingField`; a field that is genuinely sometimes-absent
(`currentWeek` on a pre-season league, a player's injury `status`) is `Int?` / `String?`.
Numeric record fields on `CDYahooTeamOutcomeTotals` / `CDYahooMatchup` default to `0` / `""`
rather than throwing, since a brand-new league legitimately has no games played yet.

---

## Error Handling

Every OAuth and Fantasy Sports method throws `CDYahooKitError`:

| Case | Meaning |
|------|---------|
| `invalidCredentials(String)` | A precondition wasn't met (empty client credentials), the OAuth `state` didn't match, no refresh token is stored, or Yahoo's token endpoint rejected the grant. The message is user-safe-ish but primarily for logs. |
| `invalidRequest(underlying: any Error)` | The `URLRequest` couldn't be built (bad URL from route params), or a non-2xx HTTP response that wasn't a recognizable `<error>` envelope. |
| `xmlParsingFailed(underlying: any Error)` | `XMLParser` failed on the response body. |
| `responseDecodingFailed(underlying: any Error)` | The XML parsed, but a model's `init(node:)` or the OAuth JSON decode threw. |
| `apiError(String)` | Yahoo returned its `<error>` envelope; the string is its `<description>`. |
| `authorizationCancelled` | The user dismissed the `ASWebAuthenticationSession` sheet. |

`CDYahooKitError` is `LocalizedError` (so `.localizedDescription` is meaningful) and
`@unchecked Sendable` — the `underlying: any Error` payloads can't be proven `Sendable` at
compile time because `any Error` erases the concrete type, but in practice every value stored
there (`URLError`, `DecodingError`, `CDYahooXMLDecodingError`) is safe to cross isolation
domains. This mirrors `CDYelpRouter`'s rationale.

There is no `nil`-on-error path — everything surfaces through `async throws`. Empty client
credentials are a `precondition` (a caller bug, enforced in Release too), not a thrown error.

---

## Concurrency & Thread Safety

| Type | Isolation | Notes |
|------|-----------|-------|
| `CDYahooFantasyAPIClient` | `@MainActor` | Call `fetch…` from the main actor or a `Task`. No `Sendable` annotation needed. |
| `CDYahooOAuthClient` | `actor` | Serializes token refresh so Yahoo's refresh-token rotation can't be raced. |
| `CDYahooURLSession` | `Sendable` `final class` | All properties immutable; delegates mutable state to the cache actor. |
| `CDYahooResponseCache` | `actor` | Backing dictionary is actor-isolated. |
| `CDYahooAuthSession` | `@unchecked Sendable` `final class` | One in-flight authorization per instance; `activeSession` is written once synchronously and cleared once from the completion callback. |
| Every model / response | `Sendable` `struct` | Value types, no reference state. |
| `CDYahooEventMonitor` / `CDYahooRequestAdapter` | `Sendable` protocols | Implementations must be safe to call from the request pipeline. |

Create **one** `CDYahooFantasyAPIClient` per app and hold a strong reference to it; don't
construct one per request (each carries its own cache and OAuth actor).

Cancellation is cooperative: cancel the `Task` wrapping a `fetch…` call. An in-flight
`URLSessionTask` is cancelled by the runtime, and a pending retry-backoff sleep throws
`CancellationError` rather than continuing.

---

## Platform-Specific Behavior

| Platform | Min OS | Interactive sign-in | Notes |
|----------|--------|---------------------|-------|
| iOS | 15.0 | ✅ `CDYahooAuthSession` | Full `ASWebAuthenticationSession` flow. |
| macOS | 12.0 | ✅ `CDYahooAuthSession` | Full flow. |
| visionOS | 1.0 | ✅ `CDYahooAuthSession` | Full flow. |
| tvOS | 15.0 | 🔲 none | `ASWebAuthenticationSession` is tvOS 16+; the whole `CDYahooAuthSession` file is compiled out. Build `authorizationURL(…)`, complete the web step out of band, call `authorize(withCode:codeVerifier:)`. |
| watchOS | 8.0 | 🔲 none | `ASWebAuthenticationSession` does not exist on watchOS. Same out-of-band approach as tvOS. |

`CDYahooAuthSession` is wrapped in `#if os(iOS) || os(macOS) || os(visionOS)` (a compile-time
exclusion, not just `@available`) precisely because an SPM-only CI job that builds for the
host alone never surfaces the tvOS/watchOS gap — this was a real CI finding during the
rewrite, which is why the CI matrix builds every platform scheme.

---

## Testing Architecture

Tests use the **Swift Testing** framework (`import Testing`, `@Suite` / `@Test` / `#expect`),
not XCTest. Two layers:

### Model-decode suites

Load a hand-authored XML fixture from `Tests/CDYahooKitTests/Fixtures/` and assert on the
decoded structure:

```swift
@Suite("CDYahooLeagueStandingsResponse Tests")
struct CDYahooLeagueStandingsResponseTests {
    @Test
    func decodesRankedTeams() throws {
        let url = try #require(Bundle.module.url(forResource: "league_standings", withExtension: "xml"))
        let node = try CDYahooXMLTreeBuilder.parse(Data(contentsOf: url))
        let response = try CDYahooLeagueStandingsResponse(node: node)
        #expect(response.teams.first?.rank == 1)
    }
}
```

### End-to-end client suites

`CDYahooMockURLProtocol` — shipped in the **`CDYahooKitTesting`** product, so downstream apps
can use it in their own suites — intercepts `URLSession` traffic and returns a pre-configured
`Stub` (`statusCode`, `data`, `headers`, `error`, `delay`). Two ways to attach a stub:

- `stubbing(_:with:)` — per-`URLRequest`-instance, via `URLProtocol.setProperty`.
- `register(stub:for:)` / `register(stubs:for:)` — per-`URL`, in a lock-protected
  dictionary, for code under test that builds its own request internally (i.e. every
  `CDYahooFantasyAPIClient` fetch method). A queue of stubs for one URL lets a test exercise
  the retry loop; `requestCount(for:)` asserts how many attempts were made.

`CDYahooMockURLProtocol.makeSession()` returns a `URLSession` wired to the protocol; pass it
as the `urlSession:` argument of `CDYahooFantasyAPIClient.init` (which forwards it to the
OAuth client too, so a single stubbed session covers both token and data traffic).

> **Known limitation.** The fixtures in `Tests/CDYahooKitTests/Fixtures/*.xml` were written
> by hand, not captured from a live Yahoo Developer Network account (none was available
> during the rewrite). They're internally consistent with the parser but unverified against
> the API's real response shape. [`Documentation/API_SCHEMA.md`](API_SCHEMA.md) maps each
> resource's request and response element tree, flags every element as verified or inferred,
> and lists what to reconcile once live access exists.

---

## Documentation Generation

API docs are generated with Swift's native **DocC** (not Jazzy):

```bash
bash scripts/generate-docs.sh
```

The script runs the same `swift package generate-documentation` invocation CI uses, then
writes `docs/.nojekyll`, a root `index.html` redirect, and `404.html` for GitHub Pages.
Every public symbol carries a `///` comment — the `documentation` CI job fails on any DocC
`warning:` line. The `docs/` directory is regenerated and committed **only** in dedicated,
release-tied commits, never bundled into a feature PR.

The short walkthrough lives in the DocC catalog (`Source/CDYahooKit.docc/GettingStarted.md`);
this repository's `Documentation/Usage.md` is the long-form guide.

---

## Why OAuth 2.0, not CDOAuth1Kit

The Fantasy Sports API requires OAuth 2.0; OAuth 1.0a is no longer usable for new API access.
`CDYahooAuthSession` is modeled directly on CDOAuth1Kit's `CDOAuth1AuthSession` (same
`ASWebAuthenticationSession` wrapper shape), but carries an OAuth 2.0 authorization code
instead of an OAuth 1.0a verifier, and `CDYahooOAuthClient` owns PKCE and silent token
refresh — neither of which OAuth 1.0a has any equivalent of.

---

## Further Reading

- [Documentation/Usage.md](Usage.md) — task-oriented usage guide
- [Documentation/API_SCHEMA.md](API_SCHEMA.md) — per-resource request/response XML schema, verified vs. inferred
- [Yahoo Fantasy Sports API guide](https://developer.yahoo.com/fantasysports/guide/)
- [OAuth 2.0 for Yahoo](https://developer.yahoo.com/oauth2/guide/)
- [RFC 7636 — PKCE](https://datatracker.ietf.org/doc/html/rfc7636)
- [CONTRIBUTING.md](../CONTRIBUTING.md)
