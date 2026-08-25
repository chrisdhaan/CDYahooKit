# CDYahooKit Rewrite: Yahoo Fantasy Sports API Swift Wrapper

**Status:** Draft for review
**Date:** 2026-08-24

## Background

CDYahooKit (est. 2016) is an Objective-C CocoaPods library that was pitched as
"an extensive wrapper for the Yahoo Developers Social and Fantasy Football
APIs." In practice it never got past OAuth 1.0a scaffolding — `Classes/Core/`
contains an empty `CDYahooKitManager` stub with no endpoint coverage. Ten
years on, most of what it targeted no longer exists.

### API audit (2026-08-24)

Confirmed dead:
- **YQL** (`query.yahooapis.com`) — retired 2019-01-03
- **Yahoo Weather API** (`weather.yahooapis.com`) — retired same day as YQL
- **Social Directory (SocDir) / Contacts API** — SocDir EOL'd 2020-06-30;
  Contacts API can't be enabled on new apps
- **Yahoo Finance API** (official) — killed 2017-05-15, no replacement
- **BOSS Search** — shut down 2016-03-31
- Groups, Answers, Pipes, Maps — all gone

Confirmed alive — the entirety of what's left on `developer.yahoo.com/api/`:
1. **Yahoo Fantasy Sports API** (`fantasysports.yahooapis.com/fantasy/v2/`) —
   football, baseball, basketball, hockey: games, leagues, teams, players,
   rosters, matchups, transactions, standings.
2. **Sign In With Yahoo** — OAuth 2.0 / OpenID Connect identity
   (`api.login.yahoo.com/oauth2/*`, `/openid/v1/userinfo`).

Two consequences that shape this design:
- **Auth moved from OAuth 1.0a to OAuth 2.0.** The old CDYahooKit depended on
  CDOAuth1Kit; the new one cannot — Fantasy Sports API requires OAuth 2.0.
  CDYahooKit needs its own OAuth 2.0 / OIDC client.
- **The API is XML-native, not JSON.** A `format=json` query parameter
  exists, but its output is inconsistent (single items vs. arrays render
  differently depending on cardinality) and all write requests (POST/PUT)
  must be XML regardless of the read format. This wrapper treats XML as the
  source of truth end to end.

### Decisions already made (see prior conversation)

- **Scope:** Yahoo Fantasy Sports API + Sign In With Yahoo. Nothing else —
  there is nothing else left to wrap.
- **Format:** Parse XML directly (Approach B below), not `format=json`.
- **v1 surface:** Read-only. Writes (lineup changes, add/drop, waiver
  claims) are a later version once the read-side XML layer is proven.
- **Platforms:** iOS 15+, macOS 12+, tvOS 15+, watchOS 8+, visionOS 1+ —
  matches CDUntappdKit and CDYelpFusionKit exactly.

## Migration pattern (from CDOAuth1Kit)

CDOAuth1Kit went through this exact Pods → modern-package migration in its
2.0 rewrite (`68aa092`, "CDOAuth1Kit 2.0.0: Swift rewrite, SPM, DocC, CI, and
modernized Example app"). CDYahooKit follows the same shape:

| Old (CDYahooKit today) | New |
|---|---|
| `CDYahooKit.podspec`, Objective-C `Classes/` | `Package.swift`, Swift `Source/` |
| CocoaPods `Core`/`OAuth` subspecs | Single `CDYahooKit` target (matches CDUntappdKit/CDYelpFusionKit — no subspec split) |
| `Example/` + `Pods.xcodeproj` symlink | `Example/` Xcode project with `Secrets.xcconfig` (gitignored) for credentials, same as CDOAuth1Kit's Discogs example |
| No CI | `.github/workflows/ci.yml` — iOS/macOS/tvOS/watchOS/visionOS + Catalyst + SwiftLint + SwiftFormat + DocC build + CodeQL, matrixed across Xcode versions, mirroring CDUntappdKit's/CDYelpFusionKit's CI jobs |
| No docs | `Source/CDYahooKit.docc/`, `Documentation/{Usage,ARCHITECTURE}.md`, `docs/` (GitHub Pages via `scripts/generate-docs.sh`) |
| No package manifest metadata | `CDOAuth1Kit`-style `Package.swift`: `swift-tools-version:6.0`, `swiftLanguageModes: [.v6]`, three library products (`CDYahooKit`, `CDYahooKitDynamic`, `CDYahooKitTesting`), `swift-docc-plugin` dependency |
| `.travis.yml` | Deleted — replaced by GitHub Actions |
| Both `CDYahooKit.xcodeproj` (SPM-backed) and `CDYahooKit.xcworkspace` at the repo root, same pairing CDOAuth1Kit uses |

`CHANGELOG.md`, `CLAUDE.md`, `CONTRIBUTING.md`, `.swiftformat`,
`.swiftformat-version`, and `.swiftlint.yml` are copied over and adapted from
CDOAuth1Kit's versions — they're already Swift-6/SPM-appropriate and don't
need to be reinvented.

## Architecture

CDYahooKit follows the CDUntappdKit/CDYelpFusionKit shape exactly at the
client/router/model layer, with one new layer neither sibling needed: an XML
tree parser sitting between the network response and the typed models.

```
CDYahooFantasyAPIClient (@MainActor)
  ├─ CDYahooOAuthClient        — OAuth2/OIDC, Keychain-backed tokens
  ├─ CDYahooRouter              — enum → URLRequest (fantasy/v2/* paths)
  └─ CDYahooURLSession
        ├─ performs the request
        ├─ CDYahooXMLNode       — parses response Data into a tree (Approach B)
        └─ hands the root node to the response type's init(node:)
```

### Components

**`CDYahooOAuthClient`** (`Sendable final class`, mirrors
`CDUntappdOAuthClient`'s shape) — holds `clientId`/`clientSecret`/
`redirectUrl`, stores the access/refresh token pair in the Keychain via a
`CDYahooKeychain` helper (same pattern as `CDUntappdKeychain`). Exposes
`isAuthorized()`, `accessToken()`, `addAuthorizationHeader(to:)`. Since
Fantasy Sports API access tokens expire, this client also owns silent
refresh: before returning a token to the session, it checks expiry and
exchanges the stored refresh token if needed (Yahoo's OAuth2 token endpoint
supports `grant_type=refresh_token`).

**`CDYahooAuthSession`** — an `async`/`await` wrapper around
`ASWebAuthenticationSession`, directly modeled on
`CDOAuth1AuthSession.swift`: same `presentationAnchor` initializer pattern,
same `activeSession` retention comment (`ASWebAuthenticationSession` doesn't
retain itself), same cancellation → typed-error mapping. The only functional
difference is what it hands back — CDOAuth1Kit's version returns a callback
URL containing `oauth_token`/`oauth_verifier` to plug into an OAuth 1.0a
three-legged handshake; this version returns a callback URL containing an
OAuth 2.0 `code` (plus `state`), which `CDYahooOAuthClient.authorize(withCode:)`
exchanges for a token pair — same shape as `CDUntappdOAuthClient.authorize
(withCode:)`. PKCE (`code_verifier`/`code_challenge`) is generated by
`CDYahooOAuthClient` and threaded through both halves of the flow.

**`CDYahooRouter`** — enum with one case per Fantasy Sports resource
(`.game`, `.league`, `.team`, `.roster`, `.players`, `.matchups`,
`.transactions`, `.standings`, ...), each carrying its resource key(s) and
query parameters, mirroring `CDYelpRouter`'s shape (`path` computed
property, `asURLRequest(...) throws`). Every case is a GET in v1. Base URL
is `https://fantasysports.yahooapis.com/fantasy/v2/`.

**`CDYahooXMLNode`** (new — the Approach B layer) — a small internal tree
type:
```swift
struct CDYahooXMLNode {
    let name: String
    var attributes: [String: String]
    var children: [CDYahooXMLNode]
    var text: String?

    func child(_ name: String) -> CDYahooXMLNode?
    func children(_ name: String) -> [CDYahooXMLNode]
    func text(_ name: String) -> String?
}
```
Built once per response by a `Foundation.XMLParser` delegate
(`CDYahooXMLTreeBuilder`) that does nothing but stack-push/pop nodes as tags
open/close — this is the *only* place `XMLParser`'s delegate callbacks are
handled directly. Every model type then implements `init(node:
CDYahooXMLNode) throws`, reading its fields via `child`/`children`/`text`,
the same way sibling-kit models implement `init(from decoder: Decoder)` for
JSON. This keeps per-resource code declarative and thin instead of each
model re-implementing SAX delegate logic (the problem with Approach A).

**`CDYahooFantasyAPIClient`** (`@MainActor`, mirrors
`CDUntappdAPIClient`) — the public surface. One `fetch...` method per
resource (`fetchLeague(leagueKey:)`, `fetchTeamRoster(teamKey:week:)`,
`fetchPlayers(leagueKey:filters:)`, etc.), each: build params → route through
`CDYahooRouter` → `session.perform(request)` → parse `Data` into a
`CDYahooXMLNode` tree → `ResponseType(node:)` → check for API-level errors →
return. Same `retryConfiguration`/`eventMonitors`/`requestAdapters`/
`cacheConfiguration` initializer parameters as the sibling kits, for
consistency (GET-only in-memory response cache applies here too, keyed the
same way `CDYelpCacheKey`/`CDUntappdCacheKey` do).

**`CDYahooKitError`** — mirrors `CDUntappdKitError`/`CDYelpNetworkError`:
`invalidCredentials`, `apiError(String)` (Fantasy API's XML error envelope),
`xmlParsingFailed(underlying: Error)`, `invalidRequest(underlying: Error)`.

### Data flow (example: fetching a league's standings)

1. Caller: `try await client.fetchStandings(leagueKey: "414.l.12345")`
2. Client builds query parameters, asks `oAuthClient` for a valid
   (refreshing if needed) bearer token, builds the request via
   `CDYahooRouter.standings(leagueKey:parameters:).asURLRequest()`
3. `CDYahooURLSession.perform` sends the request (respecting cache/retry/
   adapters/monitors exactly like the sibling kits), gets back XML `Data`
4. `CDYahooXMLTreeBuilder` parses `Data` into a `CDYahooXMLNode` tree rooted
   at `<fantasy_content>`
5. `CDYahooStandingsResponse(node:)` walks `fantasy_content > league >
   standings > teams > team` and builds typed `CDYahooTeamStanding` values
6. Client checks the parsed response for Yahoo's XML error indicators, throws
   `CDYahooKitError.apiError(...)` if present, otherwise returns the typed
   response

### Error handling

- Network/transport failures surface as `URLError` wrapped in
  `CDYahooKitError.invalidRequest(underlying:)`.
- Malformed XML (shouldn't happen against the real API, but matters for
  hostile/mocked responses in tests) throws
  `CDYahooKitError.xmlParsingFailed(underlying:)` from the tree builder
  before any model init runs.
- Yahoo's XML error envelope (an `<error>` element with a description) is
  checked once per response, mirroring how `CDUntappdAPIClient` checks
  `response.metadata.hasError()` after every fetch — surfaced as
  `CDYahooKitError.apiError(String)`.
- Expired access token + valid refresh token: handled silently inside
  `CDYahooOAuthClient` before the request is ever sent — not surfaced as an
  error.
- Expired/absent refresh token: `CDYahooKitError.invalidCredentials`, telling
  the caller to re-run the `ASWebAuthenticationSession` flow.

### Testing

Same shape as both sibling kits:
- `CDYahooKitTesting` SPM product exporting a `CDYahooMockURLProtocol` (built
  around canned XML fixture files) — same pattern as
  `CDUntappdMockURLProtocol`/`CDYelpMockURLProtocol`.
- `Tests/CDYahooKitTests/Fixtures/*.xml` — one fixture per resource type,
  captured from real (sanitized) API responses.
- Unit tests per model: feed a fixture through `CDYahooXMLTreeBuilder` →
  assert the typed model's fields. This also serves as living documentation
  of Yahoo's actual XML shapes, since Yahoo's own docs are known to be thin.
- `CDYahooXMLNode`/`CDYahooXMLTreeBuilder` gets direct unit tests independent
  of any model (malformed XML, empty elements, attribute-only nodes,
  self-closing tags) since every other parsing test depends on it being
  correct.
- OAuth flow: unit tests around token exchange/refresh request building and
  Keychain storage (mirroring `CDOAuth1SessionManagerTests`/
  `CDUntappdOAuthClient`'s test coverage), plus a manual/example-app check
  of the live `ASWebAuthenticationSession` browser round trip (this part
  can't be meaningfully unit tested, same as CDOAuth1Kit's approach).

### Example app

`Example/` — a single-screen iOS app (like CDOAuth1Kit's and CDUntappdKit's):
"Sign In With Yahoo" button → `CDYahooAuthSession` handshake → on success,
list the authenticated user's fantasy leagues for the current NFL season and
drill into one league's standings. Reads `clientId`/`clientSecret`/
`redirectUrl` from a gitignored `Example/Secrets.xcconfig`, following
CDOAuth1Kit's `Secrets.xcconfig.example` pattern exactly.

## Out of scope (for this spec)

- Write endpoints (roster/lineup changes, waiver claims, trades) — deferred
  to a v2 spec once the read-side XML layer has shipped and proven itself.
- Any non-Fantasy-Sports Yahoo API — there isn't one left worth wrapping.
- A generic reusable "CDOAuth2Kit" sibling package. CDUntappdKit already
  has its own inline OAuth2 client with no shared package, so there's
  existing precedent for each kit owning its OAuth client rather than
  factoring out a shared dependency; revisit only if a second OAuth2-based
  kit shows up later (YAGNI).
