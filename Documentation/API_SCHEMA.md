# CDYahooKit API Schema

This document maps every `fantasy/v2` resource CDYahooKit consumes to its request shape, its
response XML element tree, and the CDYahooKit model each element decodes into.

It exists because of a known v1.0.0 limitation: the XML fixtures in
[`Tests/CDYahooKitTests/Fixtures/`](../Tests/CDYahooKitTests/Fixtures/) were **hand-authored**,
not captured from a live Yahoo Developer Network account (none was available during the Swift
rewrite). They are internally consistent with `CDYahooXMLTreeBuilder` and every `init(node:)`
decoder, but unverified against the API's real response shape. This file is where that gap is
pinned down and tracked: each element below is flagged verified or inferred, and the
[Revisiting with live API access](#revisiting-with-live-api-access) section lists exactly what to
confirm when a real account becomes available.

For the request-execution pipeline (retry, cache, adapters, monitors) and the OAuth 2.0 + PKCE
flow, see [ARCHITECTURE.md](ARCHITECTURE.md). This document covers only the Fantasy Sports data
endpoints.

## Verification status legend

| Symbol | Meaning |
|--------|---------|
| 🟢 **Verified (code)** | Matches CDYahooKit source exactly — the request URI/params it builds, or the XML path a decoder reads. Facts, not assumptions. |
| 🔵 **Verified (reference)** | Corroborated by Yahoo's published Fantasy Sports API guide and/or multiple independent community wrappers. Not confirmed against a response this project captured. |
| 🟡 **Inferred** | Element name / nesting asserted only by the hand-authored fixture. Consistent with the parser; **not** confirmed against a live response. |

---

## Global request shape

| Aspect | Value | Status |
|--------|-------|--------|
| Base URL | `https://fantasysports.yahooapis.com/fantasy/v2/` | 🟢 [`CDYahooConstants.fantasyBaseURL`](../Source/CDYahooConstants.swift) |
| HTTP method | `GET` for every v1 endpoint (read-only — no write endpoints) | 🟢 [`CDYahooRouter.asURLRequest`](../Source/CDYahooRouter.swift) |
| Auth | `Authorization: Bearer {access_token}` (OAuth 2.0 access token from `CDYahooOAuthClient.validAccessToken()`) | 🟢 |
| Accept | `application/xml` | 🟢 |
| Response format | XML. CDYahooKit **never** sends `?format=json`. | 🟢 |

Historically Yahoo's guide documented the base host over plain `http://`; CDYahooKit always uses
HTTPS.

### Path-modifier syntax

Yahoo sub-resource selectors and filters are **matrix parameters** — `;key=value` appended to a
path segment — not `?key=value` query strings. CDYahooKit builds these by string interpolation in
[`CDYahooRouter.path`](../Source/CDYahooRouter.swift):

```
league/449.l.12345/scoreboard;week=8
team/449.l.12345.t.1/roster;week=8
league/449.l.12345/players;start=25
users;use_login=1/games;game_codes=nfl/leagues
```

League keys, team keys, and game codes interpolated into a **path segment** are percent-encoded
via `CDYahooRouter.percentEncodedPathSegment` (allowed set: alphanumerics + `-._~`), so a value
containing `/`, `?`, or `#` fails cleanly rather than silently reshaping the URL. Integer
modifiers (`week`, `start`) are interpolated raw — safe because they are `Int`.

### Response envelope

Every response is rooted at `<fantasy_content>` with `xml:lang` and `time` attributes:

```xml
<?xml version="1.0" encoding="UTF-8"?>
<fantasy_content xml:lang="en-US" time="1.23">
  <!-- resource or collection payload -->
</fantasy_content>
```

The user-games response additionally declares the default namespace
`xmlns="http://fantasysports.yahooapis.com/fantasy/v2/base.rng"`. `CDYahooXMLTreeBuilder` runs
`XMLParser` with namespace processing **off**, so every element is addressed by its local name
regardless of namespace. `CDYahooXMLTreeBuilder.parse` returns the `<fantasy_content>` node
itself as the tree root; every `init(node:)` starts from there (e.g. `node.child("league")`).

### Cardinality — the `count` attribute and why CDYahooKit is XML-first

Yahoo renders a collection as a **wrapper element carrying a `count` attribute**, with zero or
more child resource elements:

```xml
<teams count="2">
  <team>…</team>
  <team>…</team>
</teams>
```

A single-member collection still uses the wrapper plus one child. Yahoo's optional
`format=json` conversion **changes the JSON shape by cardinality** — a one-member collection
becomes an object, a multi-member collection becomes an array — so a JSON client must special-case
every collection field. The XML shape is uniform, so CDYahooKit reads it directly:
`node.child("teams")?.children("team") ?? []` yields `[]`, `[one]`, or `[many]` with the same
code path. This is the core reason the library parses XML rather than `format=json`.

CDYahooKit **ignores the `count` attribute entirely** — it maps whatever child elements are
present. A `count` that disagrees with the child element total would not be detected.

---

## Resources

| # | Resource | CDYahooKit method | Fixture |
|---|----------|-------------------|---------|
| 1 | [User's games & leagues](#1-users-games--leagues) | `fetchUserGames(gameCode:)` | [`UserGames.xml`](../Tests/CDYahooKitTests/Fixtures/UserGames.xml) |
| 2 | [League](#2-league) | `fetchLeague(leagueKey:)` | [`League.xml`](../Tests/CDYahooKitTests/Fixtures/League.xml) |
| 3 | [League standings](#3-league-standings) | `fetchLeagueStandings(leagueKey:)` | [`LeagueStandings.xml`](../Tests/CDYahooKitTests/Fixtures/LeagueStandings.xml) |
| 4 | [Team roster](#4-team-roster) | `fetchTeamRoster(teamKey:week:)` | [`TeamRoster.xml`](../Tests/CDYahooKitTests/Fixtures/TeamRoster.xml) |
| 5 | [League players](#5-league-players) | `fetchLeaguePlayers(leagueKey:start:)` | [`LeaguePlayers.xml`](../Tests/CDYahooKitTests/Fixtures/LeaguePlayers.xml) |
| 6 | [League scoreboard](#6-league-scoreboard) | `fetchLeagueScoreboard(leagueKey:week:)` | [`LeagueScoreboard.xml`](../Tests/CDYahooKitTests/Fixtures/LeagueScoreboard.xml) |
| 7 | [League transactions](#7-league-transactions) | `fetchLeagueTransactions(leagueKey:)` | [`LeagueTransactions.xml`](../Tests/CDYahooKitTests/Fixtures/LeagueTransactions.xml) |
| 8 | [League settings](#8-league-settings) | `fetchLeagueSettings(leagueKey:)` | [`LeagueSettings.xml`](../Tests/CDYahooKitTests/Fixtures/LeagueSettings.xml) |
| 9 | [League draft results](#9-league-draft-results) | `fetchLeagueDraftResults(leagueKey:)` | [`LeagueDraftResults.xml`](../Tests/CDYahooKitTests/Fixtures/LeagueDraftResults.xml) |
| 10 | [Team draft results](#10-team-draft-results) | `fetchTeamDraftResults(teamKey:)` | [`TeamDraftResults.xml`](../Tests/CDYahooKitTests/Fixtures/TeamDraftResults.xml) |
| 11 | [Team matchups](#11-team-matchups) | `fetchTeamMatchups(teamKey:weeks:)` | [`TeamMatchups.xml`](../Tests/CDYahooKitTests/Fixtures/TeamMatchups.xml) |
| 12 | [Team stats](#12-team-stats) | `fetchTeamStats(teamKey:coverage:)` | [`TeamStats.xml`](../Tests/CDYahooKitTests/Fixtures/TeamStats.xml) |

---

### 1. User's games & leagues

Every fantasy game (sport + season) and league the authenticated user has a team in, for one
game code.

| | |
|---|---|
| **CDYahooKit method** | `CDYahooFantasyAPIClient.fetchUserGames(gameCode:)` — `gameCode` defaults to `"nfl"` |
| **Router case** | `CDYahooRouter.userGames(gameCode:)` |
| **Response type** | [`CDYahooUserGamesResponse`](../Source/CDYahooUserGamesResponse.swift) → `[CDYahooGame]` → `[CDYahooLeagueSummary]` |
| **Fixture** | [`UserGames.xml`](../Tests/CDYahooKitTests/Fixtures/UserGames.xml) |

#### Request

```
GET https://fantasysports.yahooapis.com/fantasy/v2/users;use_login=1/games;game_codes={gameCode}/leagues
```

| Modifier | On segment | Required by CDYahooKit | Status | Notes |
|----------|-----------|-----------------------|--------|-------|
| `use_login=1` | `users` | Always sent | 🟢 | Restricts the `users` collection to the token's own user. |
| `game_codes={gameCode}` | `games` | Yes — always exactly one code | 🟢 | Yahoo accepts a comma-separated list and also allows `/games/` with no filter; CDYahooKit sends a single code. 🔵 |
| `/leagues` | trailing sub-resource | Always | 🟢 | Nests each league under its game. |

Common game codes: `nfl`, `mlb`, `nba`, `nhl` (🔵). Yahoo also accepts a numeric `game_key`.

#### Response — XML element tree

```xml
<fantasy_content xmlns="…/base.rng" xml:lang="en-US" time="1.23">
  <users count="1">
    <user>
      <guid>ABCDEF123456</guid>                <!-- present in real responses; not modeled -->
      <games count="1">
        <game>
          <game_key>449</game_key>
          <game_id>449</game_id>
          <name>Football</name>
          <code>nfl</code>
          <season>2025</season>
          <!-- real API also: type, url, is_registration_over, is_game_over, is_offseason -->
          <leagues count="1">
            <league>
              <league_key>449.l.12345</league_key>
              <league_id>12345</league_id>
              <name>My Fantasy League</name>
              <num_teams>10</num_teams>
              <!-- real API league summary here also carries url, scoring_type,
                   league_type, draft_status, current_week, start_week, end_week,
                   start_date, end_date, is_finished -->
            </league>
          </leagues>
        </game>
      </games>
    </user>
  </users>
</fantasy_content>
```

#### Element → model mapping

| XML path (from `<fantasy_content>`) | Swift property | Type | Required by decoder | Status |
|---|---|---|---|---|
| `users/user` | — (traversal anchor) | — | Yes → throws `missingField("users/user")` | 🟢 path · 🔵 element names |
| `users/user/guid` | *(not modeled)* | — | — | 🔵 |
| `users/user/games/game` | `CDYahooUserGamesResponse.games[]` | `[CDYahooGame]` | No (missing → `[]`) | 🟢 |
| `…/game/game_key` | `CDYahooGame.gameKey` | `String` | Yes | 🟢 path · 🟡 element |
| `…/game/game_id` | `CDYahooGame.gameId` | `String` | Yes | 🟢 · 🟡 |
| `…/game/name` | `CDYahooGame.name` | `String` | Yes | 🟢 · 🟡 |
| `…/game/code` | `CDYahooGame.code` | `String` | Yes | 🟢 · 🔵 |
| `…/game/season` | `CDYahooGame.season` | `String` | Yes | 🟢 · 🔵 |
| `…/game/leagues/league` | `CDYahooGame.leagues[]` | `[CDYahooLeagueSummary]` | No (missing → `[]`) | 🟢 |
| `…/league/league_key` | `CDYahooLeagueSummary.leagueKey` | `String` | Yes | 🟢 · 🔵 |
| `…/league/league_id` | `CDYahooLeagueSummary.leagueId` | `String` | Yes | 🟢 · 🔵 |
| `…/league/name` | `CDYahooLeagueSummary.name` | `String` | Yes | 🟢 · 🟡 |
| `…/league/num_teams` | `CDYahooLeagueSummary.numTeams` | `Int?` | No | 🟢 · 🟡 |

#### Cardinality notes

- `users` is always a single `user` because of `use_login=1`. The decoder reads `users/user`
  directly and does not iterate.
- `games count="N"` — one `game` per matched code (CDYahooKit sends one, so N is 0 or 1 in
  practice).
- `leagues count="N"` per game — 0 when the user has no team in that game/season.

---

### 2. League

A league's metadata and settings.

| | |
|---|---|
| **CDYahooKit method** | `CDYahooFantasyAPIClient.fetchLeague(leagueKey:)` |
| **Router case** | `CDYahooRouter.league(leagueKey:)` |
| **Response type** | [`CDYahooLeagueResponse`](../Source/CDYahooLeagueResponse.swift) → [`CDYahooLeague`](../Source/CDYahooLeague.swift) |
| **Fixture** | [`League.xml`](../Tests/CDYahooKitTests/Fixtures/League.xml) |

#### Request

```
GET https://fantasysports.yahooapis.com/fantasy/v2/league/{leagueKey}
```

| Part | Required | Status | Notes |
|------|----------|--------|-------|
| `{leagueKey}` path segment | Yes | 🟢 | Format `{game_key}.l.{league_id}`, e.g. `449.l.12345`. 🔵 Percent-encoded as a path segment. |

No modifiers. CDYahooKit does not request `;out=settings` or any other league sub-resource in v1.

#### Response — XML element tree

```xml
<fantasy_content xml:lang="en-US" time="1.23">
  <league>
    <league_key>449.l.12345</league_key>
    <league_id>12345</league_id>
    <name>My Fantasy League</name>
    <url>https://football.fantasysports.yahoo.com/f1/12345</url>
    <num_teams>10</num_teams>
    <scoring_type>head</scoring_type>       <!-- head | roto | point (🔵) -->
    <current_week>8</current_week>
    <season>2025</season>
    <!-- real API also returns: draft_status, start_date, end_date, start_week, end_week,
         edit_key, is_finished, is_pro_league, league_type, renew, renewed, felo_tier,
         num_playoff_teams, num_playoff_consolation_teams, weekly_deadline, game_code,
         allow_add_to_dl_extra_pos, logo_url, password, short_invitation_url, … — none modeled -->
  </league>
</fantasy_content>
```

#### Element → model mapping

| XML path (from `<fantasy_content>`) | Swift property | Type | Required by decoder | Status |
|---|---|---|---|---|
| `league` | — (anchor) | — | Yes → throws `missingField("league")` | 🟢 · 🔵 |
| `league/league_key` | `CDYahooLeague.leagueKey` | `String` | Yes | 🟢 · 🔵 |
| `league/league_id` | `CDYahooLeague.leagueId` | `String` | Yes | 🟢 · 🔵 |
| `league/name` | `CDYahooLeague.name` | `String` | Yes | 🟢 · 🔵 |
| `league/url` | `CDYahooLeague.url` | `String?` | No | 🟢 · 🔵 |
| `league/num_teams` | `CDYahooLeague.numTeams` | `Int?` | No | 🟢 · 🔵 |
| `league/scoring_type` | `CDYahooLeague.scoringType` | `String?` | No | 🟢 · 🔵 |
| `league/current_week` | `CDYahooLeague.currentWeek` | `Int?` | No | 🟢 · 🔵 |
| `league/season` | `CDYahooLeague.season` | `String?` | No | 🟢 · 🔵 |

#### Cardinality notes

- Single resource, no collection wrapper.
- Every field except the three keys is optional in the decoder; a partially-populated `<league>`
  (e.g. pre-draft, no `current_week`) still decodes.

---

### 3. League standings

Teams in a league ranked by standing, with each team's win/loss record and points.

| | |
|---|---|
| **CDYahooKit method** | `CDYahooFantasyAPIClient.fetchLeagueStandings(leagueKey:)` |
| **Router case** | `CDYahooRouter.standings(leagueKey:)` |
| **Response type** | [`CDYahooLeagueStandingsResponse`](../Source/CDYahooLeagueStandingsResponse.swift) → `[CDYahooTeamStanding]` → `CDYahooTeamOutcomeTotals` |
| **Fixture** | [`LeagueStandings.xml`](../Tests/CDYahooKitTests/Fixtures/LeagueStandings.xml) |

#### Request

```
GET https://fantasysports.yahooapis.com/fantasy/v2/league/{leagueKey}/standings
```

No modifiers. `standings` implicitly includes the `teams` sub-resource with `team_standings` (🔵).

#### Response — XML element tree

```xml
<fantasy_content xml:lang="en-US" time="1.23">
  <league>
    <league_key>449.l.12345</league_key>
    <name>My Fantasy League</name>          <!-- fixture echoes it; decoder ignores it — see notes -->
    <standings>
      <teams count="2">
        <team>
          <team_key>449.l.12345.t.1</team_key>
          <team_id>1</team_id>
          <name>Team Alpha</name>
          <!-- real API team here also: url, team_logos, waiver_priority, number_of_moves,
               number_of_trades, roster_adds, league_scoring_type, division_id, managers -->
          <team_standings>
            <rank>1</rank>
            <!-- real API also: playoff_seed -->
            <outcome_totals>
              <wins>8</wins>
              <losses>3</losses>
              <ties>0</ties>
              <percentage>.727</percentage>   <!-- leading-dot string, no leading zero (🔵) -->
            </outcome_totals>
            <!-- real API also: <streak><type>win</type><value>3</value></streak> -->
            <points_for>1234.5</points_for>
            <points_against>1100.2</points_against>
          </team_standings>
        </team>
        <team>…</team>
      </teams>
    </standings>
  </league>
</fantasy_content>
```

#### Element → model mapping

| XML path (from `<fantasy_content>`) | Swift property | Type | Required by decoder | Status |
|---|---|---|---|---|
| `league/league_key` | `CDYahooLeagueStandingsResponse.leagueKey` | `String` | Yes → throws `missingField("league")` | 🟢 · 🔵 |
| `league/standings/teams/team` | `.teams[]` | `[CDYahooTeamStanding]` | No (missing → `[]`) | 🟢 · 🟡 |
| `…/team/team_key` | `CDYahooTeamStanding.teamKey` | `String` | Yes → `missingField("team")` | 🟢 · 🔵 |
| `…/team/team_id` | `CDYahooTeamStanding.teamId` | `String` | Yes | 🟢 · 🔵 |
| `…/team/name` | `CDYahooTeamStanding.name` | `String` | Yes | 🟢 · 🔵 |
| `…/team/team_standings/rank` | `CDYahooTeamStanding.rank` | `Int?` | No | 🟢 · 🔵 |
| `…/team_standings/outcome_totals` | `CDYahooTeamStanding.outcomeTotals` | `CDYahooTeamOutcomeTotals?` | No | 🟢 · 🔵 |
| `…/outcome_totals/wins` | `CDYahooTeamOutcomeTotals.wins` | `Int` (default `0`) | No | 🟢 · 🔵 |
| `…/outcome_totals/losses` | `.losses` | `Int` (default `0`) | No | 🟢 · 🔵 |
| `…/outcome_totals/ties` | `.ties` | `Int` (default `0`) | No | 🟢 · 🔵 |
| `…/outcome_totals/percentage` | `.percentage` | `String` (default `"0.000"`) | No | 🟢 · 🔵 |
| `…/team_standings/points_for` | `CDYahooTeamStanding.pointsFor` | `Double?` | No | 🟢 · 🔵 |
| `…/team_standings/points_against` | `CDYahooTeamStanding.pointsAgainst` | `Double?` | No | 🟢 · 🔵 |

#### Cardinality notes

- `teams count="N"` — one `team` per league member.
- `team_standings` is optional in the decoder: a standings call made before any games are played
  (no rank/record yet) still decodes, with `outcomeTotals == nil`.
- **🟡 The fixture puts `<name>` directly under `<league>` in the standings response.** The
  decoder only reads `league_key` at that level, so whether Yahoo actually echoes the league
  `name` here is unverified and immaterial to decoding.
- `percentage` is kept as a `String` deliberately — Yahoo emits `.727` (no leading zero), which
  is lossy to parse and re-render as a `Double`.

---

### 4. Team roster

A team's players, optionally as set for a specific week.

| | |
|---|---|
| **CDYahooKit method** | `CDYahooFantasyAPIClient.fetchTeamRoster(teamKey:week:)` — `week: Int?` |
| **Router case** | `CDYahooRouter.roster(teamKey:week:)` |
| **Response type** | [`CDYahooTeamRosterResponse`](../Source/CDYahooTeamRosterResponse.swift) → `[CDYahooPlayer]` |
| **Fixture** | [`TeamRoster.xml`](../Tests/CDYahooKitTests/Fixtures/TeamRoster.xml) |

#### Request

```
GET …/fantasy/v2/team/{teamKey}/roster                 (week == nil)
GET …/fantasy/v2/team/{teamKey}/roster;week={week}     (week != nil)
```

| Modifier | Required | Status | Notes |
|----------|----------|--------|-------|
| `{teamKey}` path segment | Yes | 🟢 | Format `{league_key}.t.{team_id}`, e.g. `449.l.12345.t.1`. 🔵 |
| `;week={week}` | No | 🟢 | Integer, interpolated raw. Omitted entirely when `week == nil` → current roster. |

**Limitation (🟢):** only `;week=` is exposed. Yahoo's baseball/basketball/hockey games use
`;date=YYYY-MM-DD` instead of `;week=` (🔵) — CDYahooKit has no parameter for that.

#### Response — XML element tree

```xml
<fantasy_content xml:lang="en-US" time="1.23">
  <team>
    <team_key>449.l.12345.t.1</team_key>
    <name>Team Alpha</name>
    <roster>
      <!-- real API: <roster coverage_type="week" week="8" is_editable="1"> -->
      <players count="2">
        <player>
          <player_key>449.p.30123</player_key>
          <player_id>30123</player_id>
          <name>
            <full>Jane Doe</full>
            <!-- real API also: first, last, ascii_first, ascii_last -->
          </name>
          <editorial_team_abbr>SF</editorial_team_abbr>
          <display_position>QB</display_position>
          <selected_position>
            <!-- real API also: coverage_type, week, is_flex -->
            <position>QB</position>            <!-- "BN" = bench, "IR" = injured reserve -->
          </selected_position>
          <!-- real API player also: editorial_player_key, editorial_team_key,
               editorial_team_full_name, uniform_number, position_type,
               eligible_positions/position*, headshot, is_undroppable, status,
               status_full, injury_note, bye_weeks/week -->
        </player>
        <player>… selected_position/position = "BN" …</player>
      </players>
    </roster>
  </team>
</fantasy_content>
```

#### Element → model mapping

| XML path (from `<fantasy_content>`) | Swift property | Type | Required by decoder | Status |
|---|---|---|---|---|
| `team/team_key` | `CDYahooTeamRosterResponse.teamKey` | `String` | Yes → `missingField("team")` | 🟢 · 🔵 |
| `team/name` | `CDYahooTeamRosterResponse.name` | `String` | Yes | 🟢 · 🔵 |
| `team/roster/players/player` | `.players[]` | `[CDYahooPlayer]` | No (missing → `[]`) | 🟢 · 🔵 |
| `…/player/player_key` | `CDYahooPlayer.playerKey` | `String` | Yes → `missingField("player")` | 🟢 · 🔵 |
| `…/player/player_id` | `CDYahooPlayer.playerId` | `String` | Yes | 🟢 · 🔵 |
| `…/player/name/full` | `CDYahooPlayer.fullName` | `String` | Yes | 🟢 · 🔵 |
| `…/player/editorial_team_abbr` | `CDYahooPlayer.editorialTeamAbbr` | `String?` | No | 🟢 · 🔵 |
| `…/player/display_position` | `CDYahooPlayer.displayPosition` | `String?` | No | 🟢 · 🔵 |
| `…/player/selected_position/position` | `CDYahooPlayer.selectedPosition` | `String?` | No | 🟢 · 🔵 |
| `…/player/status` | `CDYahooPlayer.status` | `String?` | No | 🟢 · 🔵 |

#### Cardinality notes

- `players count="N"` — one `player` per roster slot (starters, bench, IR).
- `selected_position` is a single element per player and appears **only** in roster context.
  `CDYahooPlayer` is shared with [League players](#5-league-players), where `selectedPosition` is
  always `nil`.
- A missing / self-closing `<status/>` decodes to `nil` (`CDYahooXMLNode.text(_:)` treats empty
  as absent).
- **🟡** Real rosters carry `eligible_positions` (a `position` collection) and richer `name`
  sub-elements; CDYahooKit models neither. `selected_position` position codes seen in the wild:
  real position abbreviations, plus `BN` (bench) and `IR`.

---

### 5. League players

The league's player pool, paged.

| | |
|---|---|
| **CDYahooKit method** | `CDYahooFantasyAPIClient.fetchLeaguePlayers(leagueKey:start:)` — `start: Int?`, zero-based |
| **Router case** | `CDYahooRouter.players(leagueKey:start:)` |
| **Response type** | [`CDYahooLeaguePlayersResponse`](../Source/CDYahooLeaguePlayersResponse.swift) → `[CDYahooPlayer]` |
| **Fixture** | [`LeaguePlayers.xml`](../Tests/CDYahooKitTests/Fixtures/LeaguePlayers.xml) |

#### Request

```
GET …/fantasy/v2/league/{leagueKey}/players                  (start == nil)
GET …/fantasy/v2/league/{leagueKey}/players;start={start}    (start != nil)
```

| Modifier | Required | Status | Notes |
|----------|----------|--------|-------|
| `{leagueKey}` path segment | Yes | 🟢 | |
| `;start={start}` | No | 🟢 | Zero-based offset. Omitted when `start == nil` → first page. |

**Limitation (🟢):** `start` is the only knob CDYahooKit exposes. Yahoo also supports `;count=`
(page size, max 25), and the filters `;status=`, `;position=`, `;search=`, `;sort=`, `;sort_type=`
(🔵). Default page size is 25, so a caller pages by advancing `start` in steps of 25.

#### Response — XML element tree

```xml
<fantasy_content xml:lang="en-US" time="1.23">
  <league>
    <league_key>449.l.12345</league_key>
    <players count="2">
      <player>
        <player_key>449.p.30123</player_key>
        <player_id>30123</player_id>
        <name>
          <full>Jane Doe</full>
        </name>
        <editorial_team_abbr>SF</editorial_team_abbr>
        <display_position>QB</display_position>
        <status>ACT</status>
      </player>
      <player>
        <player_key>449.p.30789</player_key>
        <player_id>30789</player_id>
        <name><full>Sam Lee</full></name>
        <editorial_team_abbr>NYJ</editorial_team_abbr>
        <display_position>WR</display_position>
        <status/>                              <!-- self-closing → decodes to nil -->
      </player>
      <!-- real API player pool entries also nest <ownership><ownership_type>…</ownership_type>…
           and the collection carries pagination context — none modeled -->
    </players>
  </league>
</fantasy_content>
```

#### Element → model mapping

| XML path (from `<fantasy_content>`) | Swift property | Type | Required by decoder | Status |
|---|---|---|---|---|
| `league/league_key` | `CDYahooLeaguePlayersResponse.leagueKey` | `String` | Yes → `missingField("league")` | 🟢 · 🔵 |
| `league/players/player` | `.players[]` | `[CDYahooPlayer]` | No (missing → `[]`) | 🟢 · 🟡 |
| `…/player/*` | `CDYahooPlayer` fields | — | see [Team roster](#4-team-roster) mapping | 🟢 · 🔵 |

`<players>` is read **directly under `<league>`** here — not under a `roster` or `standings`
wrapper as in the roster response.

#### Cardinality notes

- `players count="N"` — up to the page size (25).
- `selected_position` never appears in this context → `CDYahooPlayer.selectedPosition` is always
  `nil` for league-pool players.
- **🟡** The real league-players collection is widely documented to carry per-player `ownership`
  data and pagination metadata on the collection element. CDYahooKit reads neither, and there is
  no fixture element for them.

---

### 6. League scoreboard

Every head-to-head matchup for a week.

| | |
|---|---|
| **CDYahooKit method** | `CDYahooFantasyAPIClient.fetchLeagueScoreboard(leagueKey:week:)` — `week: Int?` |
| **Router case** | `CDYahooRouter.scoreboard(leagueKey:week:)` |
| **Response type** | [`CDYahooLeagueScoreboardResponse`](../Source/CDYahooLeagueScoreboardResponse.swift) → `[CDYahooMatchup]` → `[CDYahooMatchupTeamScore]` |
| **Fixture** | [`LeagueScoreboard.xml`](../Tests/CDYahooKitTests/Fixtures/LeagueScoreboard.xml) |

#### Request

```
GET …/fantasy/v2/league/{leagueKey}/scoreboard                 (week == nil)
GET …/fantasy/v2/league/{leagueKey}/scoreboard;week={week}     (week != nil)
```

| Modifier | Required | Status | Notes |
|----------|----------|--------|-------|
| `{leagueKey}` path segment | Yes | 🟢 | |
| `;week={week}` | No | 🟢 | Integer, raw. Omitted → current week. |

#### Response — XML element tree

```xml
<fantasy_content xml:lang="en-US" time="1.23">
  <league>
    <league_key>449.l.12345</league_key>
    <scoreboard>
      <!-- real API: <scoreboard week="8"> -->
      <matchups count="1">
        <matchup>
          <week>8</week>
          <status>postevent</status>          <!-- preevent | midevent | postevent (🔵) -->
          <!-- real API also: week_start, week_end, is_playoffs, is_consolation,
               is_matchup_recap_available, is_tied, winner_team_key, matchup_recap_url -->
          <teams count="2">
            <team>
              <team_key>449.l.12345.t.1</team_key>
              <name>Team Alpha</name>
              <team_points>
                <!-- real API: <team_points><coverage_type>week</coverage_type>
                     <week>8</week><total>112.5</total></team_points> -->
                <total>112.5</total>
              </team_points>
              <!-- real API team also: team_projected_points, win_probability -->
            </team>
            <team>… Team Beta, total 98.4 …</team>
          </teams>
        </matchup>
      </matchups>
    </scoreboard>
  </league>
</fantasy_content>
```

#### Element → model mapping

| XML path (from `<fantasy_content>`) | Swift property | Type | Required by decoder | Status |
|---|---|---|---|---|
| `league/league_key` | `CDYahooLeagueScoreboardResponse.leagueKey` | `String` | Yes → `missingField("league")` | 🟢 · 🔵 |
| `league/scoreboard/matchups/matchup` | `.matchups[]` | `[CDYahooMatchup]` | No (missing → `[]`) | 🟢 · 🔵 |
| `…/matchup/week` | `CDYahooMatchup.week` | `Int` (default `0`) | No | 🟢 · 🔵 |
| `…/matchup/status` | `CDYahooMatchup.status` | `String` (default `""`) | No | 🟢 · 🔵 |
| `…/matchup/teams/team` | `CDYahooMatchup.teams[]` | `[CDYahooMatchupTeamScore]` | No (missing → `[]`) | 🟢 · 🔵 |
| `…/team/team_key` | `CDYahooMatchupTeamScore.teamKey` | `String` | Yes → `missingField("team")` | 🟢 · 🔵 |
| `…/team/name` | `CDYahooMatchupTeamScore.name` | `String` | Yes | 🟢 · 🔵 |
| `…/team/team_points/total` | `CDYahooMatchupTeamScore.totalPoints` | `Double?` | No | 🟢 · 🟡 |

#### Cardinality notes

- `matchups count="N"` — one `matchup` per pair of teams (a bye week may produce a matchup with a
  single team).
- `teams count="2"` — the decoder does not assume exactly two; it maps whatever `team` elements
  are present.
- **🟡** `<team_points>` in the fixture contains only `<total>`. Real responses wrap `total`
  alongside `coverage_type` and `week`. The decoder reads `team_points/total` only, so the extra
  elements are harmless but unverified.

---

### 7. League transactions

Adds, drops, trades, and waiver claims in a league.

| | |
|---|---|
| **CDYahooKit method** | `CDYahooFantasyAPIClient.fetchLeagueTransactions(leagueKey:)` |
| **Router case** | `CDYahooRouter.transactions(leagueKey:)` |
| **Response type** | [`CDYahooLeagueTransactionsResponse`](../Source/CDYahooLeagueTransactionsResponse.swift) → `[CDYahooTransaction]` → `[CDYahooTransactionPlayer]` |
| **Fixture** | [`LeagueTransactions.xml`](../Tests/CDYahooKitTests/Fixtures/LeagueTransactions.xml) |

#### Request

```
GET …/fantasy/v2/league/{leagueKey}/transactions
```

No modifiers. **Limitation (🟢):** CDYahooKit sends no filters, so Yahoo returns its default
transaction set. Yahoo supports `;type=`, `;types=add,drop,commish,trade`, `;team_key=`, and
`;count=` (🔵) — none are exposed.

#### Response — XML element tree

```xml
<fantasy_content xml:lang="en-US" time="1.23">
  <league>
    <league_key>449.l.12345</league_key>
    <transactions count="1">
      <transaction>
        <transaction_key>449.l.12345.tr.1</transaction_key>
        <transaction_id>1</transaction_id>
        <type>add/drop</type>                 <!-- add | drop | add/drop | trade | commish (🔵) -->
        <status>successful</status>           <!-- successful | pending | vetoed (🔵) -->
        <!-- real API also: timestamp; for waivers faab_bid;
             for pending trades trader_team_key, tradee_team_key,
             trade_proposed_time, trade_note -->
        <players count="1">
          <player>
            <player_key>449.p.30789</player_key>
            <name>
              <full>Sam Lee</full>
            </name>
            <transaction_data>
              <!-- real API also: source_team_key, source_type, destination_type -->
              <type>add</type>                <!-- the per-player move: add | drop -->
              <destination_team_key>449.l.12345.t.1</destination_team_key>
            </transaction_data>
          </player>
        </players>
      </transaction>
    </transactions>
  </league>
</fantasy_content>
```

#### Element → model mapping

| XML path (from `<fantasy_content>`) | Swift property | Type | Required by decoder | Status |
|---|---|---|---|---|
| `league/league_key` | `CDYahooLeagueTransactionsResponse.leagueKey` | `String` | Yes → `missingField("league")` | 🟢 · 🔵 |
| `league/transactions/transaction` | `.transactions[]` | `[CDYahooTransaction]` | No (missing → `[]`) | 🟢 · 🔵 |
| `…/transaction/transaction_key` | `CDYahooTransaction.transactionKey` | `String` | Yes → `missingField("transaction")` | 🟢 · 🔵 |
| `…/transaction/transaction_id` | `CDYahooTransaction.transactionId` | `String` | Yes | 🟢 · 🔵 |
| `…/transaction/type` | `CDYahooTransaction.type` | `String` | Yes | 🟢 · 🔵 |
| `…/transaction/status` | `CDYahooTransaction.status` | `String` | Yes | 🟢 · 🔵 |
| `…/transaction/players/player` | `CDYahooTransaction.players[]` | `[CDYahooTransactionPlayer]` | No (missing → `[]`) | 🟢 · 🔵 |
| `…/player/player_key` | `CDYahooTransactionPlayer.playerKey` | `String` | Yes → `missingField("player")` | 🟢 · 🔵 |
| `…/player/name/full` | `CDYahooTransactionPlayer.fullName` | `String` | Yes | 🟢 · 🔵 |
| `…/player/transaction_data/type` | `CDYahooTransactionPlayer.transactionType` | `String?` | No | 🟢 · 🔵 |
| `…/player/transaction_data/destination_team_key` | `CDYahooTransactionPlayer.destinationTeamKey` | `String?` | No | 🟢 · 🔵 |

#### Cardinality notes

- `transactions count="N"` — most recent first (🔵).
- `players count="M"` — 1 for an add or a drop, 2 for an add/drop, 2 for a trade.
- **🟡 Known model gap:** for a **trade**, Yahoo nests **two `<transaction_data>` elements per
  player** (the move out of one roster and into the other). `CDYahooTransactionPlayer.init(node:)`
  reads a single `node.child("transaction_data")`, so only the first move is captured. Confirm and
  fix against a real trade payload — see [below](#revisiting-with-live-api-access).
- Real transactions also carry a `timestamp` and, for waiver claims, a `faab_bid`. Neither is
  modeled.

---

### 8. League settings

A league's configuration: scoring type, roster shape, the stat categories it scores and their
point values, and its waiver, trade, and playoff rules.

| | |
|---|---|
| **CDYahooKit method** | `CDYahooFantasyAPIClient.fetchLeagueSettings(leagueKey:)` |
| **Router case** | `CDYahooRouter.settings(leagueKey:)` |
| **Response type** | [`CDYahooLeagueSettingsResponse`](../Source/CDYahooLeagueSettingsResponse.swift) → [`CDYahooLeagueSettings`](../Source/CDYahooLeagueSettingsResponse.swift) → `[CDYahooRosterPosition]` / `[CDYahooStatCategory]` / `[CDYahooStatModifier]` |
| **Fixture** | [`LeagueSettings.xml`](../Tests/CDYahooKitTests/Fixtures/LeagueSettings.xml) |

#### Request

```
GET https://fantasysports.yahooapis.com/fantasy/v2/league/{leagueKey}/settings
```

No modifiers. The `settings` sub-resource is returned nested under the `<league>` resource
element (🔵).

#### Response — XML element tree

```xml
<fantasy_content xml:lang="en-US" time="1.23">
  <league>
    <league_key>449.l.12345</league_key>
    <league_id>12345</league_id>
    <name>My Fantasy League</name>
    <settings>
      <scoring_type>head</scoring_type>              <!-- head | roto | point (🔵) -->
      <uses_playoff>1</uses_playoff>                 <!-- 1 | 0 -->
      <playoff_start_week>15</playoff_start_week>
      <num_playoff_teams>6</num_playoff_teams>
      <num_playoff_consolation_teams>4</num_playoff_consolation_teams>
      <uses_playoff_reseeding>0</uses_playoff_reseeding>
      <waiver_type>R</waiver_type>                   <!-- R (rolling) | FR | C (🔵) -->
      <waiver_rule>gametime</waiver_rule>
      <uses_faab>0</uses_faab>
      <waiver_time>2</waiver_time>
      <trade_end_date>2025-11-14</trade_end_date>
      <trade_ratify_type>commish</trade_ratify_type> <!-- commish | vote | none (🔵) -->
      <trade_reject_time>2</trade_reject_time>
      <!-- real API settings also: draft_type, is_auction_draft, persistent_url,
           has_playoff_consolation_games, draft_time, draft_pick_time, post_draft_players,
           max_teams, player_pool, cant_cut_list, can_trade_draft_picks, … — none modeled -->
      <roster_positions>
        <roster_position>
          <position>QB</position>
          <position_type>O</position_type>          <!-- O (offense) | DT | DP | P | K … (🔵) -->
          <count>1</count>
        </roster_position>
        <roster_position>
          <position>BN</position>                    <!-- BN = bench; IR also seen -->
          <count>5</count>
        </roster_position>
      </roster_positions>
      <stat_categories>
        <stats>
          <stat>
            <stat_id>4</stat_id>
            <enabled>1</enabled>
            <name>Passing Yards</name>
            <display_name>Pass Yds</display_name>
            <sort_order>1</sort_order>
            <position_type>O</position_type>
            <!-- real API also: stat_position_types, is_only_display_stat -->
          </stat>
          <stat>…</stat>
        </stats>
      </stat_categories>
      <stat_modifiers>
        <stats>
          <stat>
            <stat_id>4</stat_id>
            <value>0.04</value>
          </stat>
          <stat>…</stat>
        </stats>
      </stat_modifiers>
    </settings>
  </league>
</fantasy_content>
```

#### Element → model mapping

| XML path (from `<fantasy_content>`) | Swift property | Type | Required by decoder | Status |
|---|---|---|---|---|
| `league/league_key` | `CDYahooLeagueSettingsResponse.leagueKey` | `String` | Yes → throws `missingField("league/settings")` | 🟢 · 🔵 |
| `league/settings` | — (anchor) | — | Yes → throws `missingField("league/settings")` | 🟢 · 🔵 |
| `…/settings/scoring_type` | `CDYahooLeagueSettings.scoringType` | `String?` | No | 🟢 · 🔵 |
| `…/settings/uses_playoff` | `.usesPlayoff` | `Bool?` (`"1"`/`"0"`) | No | 🟢 · 🔵 |
| `…/settings/playoff_start_week` | `.playoffStartWeek` | `Int?` | No | 🟢 · 🔵 |
| `…/settings/num_playoff_teams` | `.numPlayoffTeams` | `Int?` | No | 🟢 · 🔵 |
| `…/settings/num_playoff_consolation_teams` | `.numPlayoffConsolationTeams` | `Int?` | No | 🟢 · 🔵 |
| `…/settings/uses_playoff_reseeding` | `.usesPlayoffReseeding` | `Bool?` | No | 🟢 · 🔵 |
| `…/settings/waiver_type` | `.waiverType` | `String?` | No | 🟢 · 🔵 |
| `…/settings/waiver_rule` | `.waiverRule` | `String?` | No | 🟢 · 🔵 |
| `…/settings/uses_faab` | `.usesFaab` | `Bool?` | No | 🟢 · 🔵 |
| `…/settings/waiver_time` | `.waiverTime` | `Int?` | No | 🟢 · 🔵 |
| `…/settings/trade_end_date` | `.tradeEndDate` | `String?` (`YYYY-MM-DD`) | No | 🟢 · 🔵 |
| `…/settings/trade_ratify_type` | `.tradeRatifyType` | `String?` | No | 🟢 · 🔵 |
| `…/settings/trade_reject_time` | `.tradeRejectTime` | `Int?` | No | 🟢 · 🔵 |
| `…/settings/roster_positions/roster_position` | `.rosterPositions[]` | `[CDYahooRosterPosition]` | No (missing → `[]`) | 🟢 · 🟡 |
| `…/roster_position/position` | `CDYahooRosterPosition.position` | `String` | Yes → `missingField("roster_position")` | 🟢 · 🔵 |
| `…/roster_position/position_type` | `.positionType` | `String?` | No | 🟢 · 🔵 |
| `…/roster_position/count` | `.count` | `Int` (default `0`) | No | 🟢 · 🔵 |
| `…/settings/stat_categories/stats/stat` | `.statCategories[]` | `[CDYahooStatCategory]` | No (missing → `[]`) | 🟢 · 🟡 |
| `…/stat_categories/…/stat/stat_id` | `CDYahooStatCategory.statId` | `Int` | Yes → `missingField("stat")` | 🟢 · 🔵 |
| `…/stat/name` | `.name` | `String` | Yes | 🟢 · 🔵 |
| `…/stat/display_name` | `.displayName` | `String?` | No | 🟢 · 🔵 |
| `…/stat/enabled` | `.enabled` | `Bool` (default `true`) | No | 🟢 · 🔵 |
| `…/stat/sort_order` | `.sortOrder` | `Int?` | No | 🟢 · 🔵 |
| `…/stat/position_type` | `.positionType` | `String?` | No | 🟢 · 🔵 |
| `…/settings/stat_modifiers/stats/stat` | `.statModifiers[]` | `[CDYahooStatModifier]` | No (missing → `[]`) | 🟢 · 🟡 |
| `…/stat_modifiers/…/stat/stat_id` | `CDYahooStatModifier.statId` | `Int` | Yes → `missingField("stat")` | 🟢 · 🔵 |
| `…/stat_modifiers/…/stat/value` | `CDYahooStatModifier.value` | `Double` | Yes | 🟢 · 🔵 |

#### Cardinality notes

- `roster_positions`, `stat_categories/stats`, and `stat_modifiers/stats` are each a wrapper with
  zero or more children; a settings response fetched before the league is configured still decodes
  with those arrays empty.
- **Stat categories and modifiers are two parallel lists**, joined on `stat_id` — a category
  carries the stat's identity, its modifier (when the league assigns one) carries the point value.
  CDYahooKit keeps them parallel rather than merging.
- **🟡** Real settings responses carry a much larger flat field set (draft config, `max_teams`,
  `player_pool`, consolation-game flags, …) and richer `stat` sub-elements
  (`stat_position_types`, `is_only_display_stat`). CDYahooKit models a curated subset covering
  scoring, roster shape, and waiver/trade/playoff rules; the element names and `settings` nesting
  are asserted only by the hand-authored fixture.

---

### 9. League draft results

Every pick made in a league's draft.

| | |
|---|---|
| **CDYahooKit method** | `CDYahooFantasyAPIClient.fetchLeagueDraftResults(leagueKey:)` |
| **Router case** | `CDYahooRouter.leagueDraftResults(leagueKey:)` |
| **Response type** | [`CDYahooLeagueDraftResultsResponse`](../Source/CDYahooDraftResultsResponse.swift) → `[CDYahooDraftResult]` |
| **Fixture** | [`LeagueDraftResults.xml`](../Tests/CDYahooKitTests/Fixtures/LeagueDraftResults.xml) |

#### Request

```
GET …/fantasy/v2/league/{leagueKey}/draftresults
```

No modifiers. Before the league drafts, Yahoo returns an empty `<draft_results>` collection.

#### Response — XML element tree

```xml
<fantasy_content xml:lang="en-US" time="1.23">
  <league>
    <league_key>449.l.12345</league_key>
    <draft_results count="2">
      <draft_result>
        <pick>1</pick>
        <round>1</round>
        <cost>52</cost>                       <!-- auction drafts only; absent for a snake draft -->
        <team_key>449.l.12345.t.3</team_key>
        <player_key>449.p.31883</player_key>
      </draft_result>
      <!-- … one <draft_result> per pick, in pick order -->
    </draft_results>
  </league>
</fantasy_content>
```

#### Element → model mapping

| XML path (from `<fantasy_content>`) | Swift property | Type | Required by decoder | Status |
|---|---|---|---|---|
| `league/league_key` | `CDYahooLeagueDraftResultsResponse.leagueKey` | `String` | Yes → `missingField("league")` | 🟢 · 🔵 |
| `league/draft_results/draft_result` | `.draftResults[]` | `[CDYahooDraftResult]` | No (missing → `[]`) | 🟢 · 🟡 |
| `…/draft_result/pick` | `CDYahooDraftResult.pick` | `Int` | Yes → `missingField("draft_result")` | 🟢 · 🔵 |
| `…/draft_result/round` | `.round` | `Int` | Yes | 🟢 · 🔵 |
| `…/draft_result/cost` | `.cost` | `Int?` | No | 🟢 · 🔵 |
| `…/draft_result/team_key` | `.teamKey` | `String` | Yes | 🟢 · 🔵 |
| `…/draft_result/player_key` | `.playerKey` | `String` | Yes | 🟢 · 🔵 |

#### Cardinality notes

- `draft_results count="N"` — one `<draft_result>` per pick, in pick order (🔵). Empty before the
  draft.
- `cost` is present only for auction drafts. `CDYahooDraftResult.cost` is `Int?`; a snake draft
  decodes it as `nil`.

---

### 10. Team draft results

One team's picks from the league's draft — the same `draftresults` sub-resource, scoped to a team.

| | |
|---|---|
| **CDYahooKit method** | `CDYahooFantasyAPIClient.fetchTeamDraftResults(teamKey:)` |
| **Router case** | `CDYahooRouter.teamDraftResults(teamKey:)` |
| **Response type** | [`CDYahooTeamDraftResultsResponse`](../Source/CDYahooDraftResultsResponse.swift) → `[CDYahooDraftResult]` |
| **Fixture** | [`TeamDraftResults.xml`](../Tests/CDYahooKitTests/Fixtures/TeamDraftResults.xml) |

#### Request

```
GET …/fantasy/v2/team/{teamKey}/draftresults
```

No modifiers.

#### Response — XML element tree

```xml
<fantasy_content xml:lang="en-US" time="1.23">
  <team>
    <team_key>449.l.67890.t.5</team_key>
    <name>Gridiron Giants</name>
    <draft_results count="2">
      <draft_result>
        <pick>5</pick>
        <round>1</round>
        <team_key>449.l.67890.t.5</team_key>
        <player_key>449.p.31883</player_key>
      </draft_result>
      <!-- … one <draft_result> per pick this team made -->
    </draft_results>
  </team>
</fantasy_content>
```

#### Element → model mapping

| XML path (from `<fantasy_content>`) | Swift property | Type | Required by decoder | Status |
|---|---|---|---|---|
| `team/team_key` | `CDYahooTeamDraftResultsResponse.teamKey` | `String` | Yes → `missingField("team")` | 🟢 · 🔵 |
| `team/draft_results/draft_result` | `.draftResults[]` | `[CDYahooDraftResult]` | No (missing → `[]`) | 🟢 · 🟡 |
| `…/draft_result/*` | `CDYahooDraftResult` | — | same shape as resource #9 | 🟢 · 🔵 |

#### Cardinality notes

- `draft_results` here holds only the picks this team made (🔵).
- `<name>` is echoed alongside `<team_key>` in the fixture but not modeled — `CDYahooTeamDraftResultsResponse`
  carries only `teamKey` and `draftResults`.

---

### 11. Team matchups

One team's schedule of head-to-head matchups, each with both sides' scores. The same `<matchup>`
element the league [scoreboard](#6-league-scoreboard) returns, scoped to a team and carrying the
richer week-boundary / outcome fields.

| | |
|---|---|
| **CDYahooKit method** | `CDYahooFantasyAPIClient.fetchTeamMatchups(teamKey:weeks:)` — `weeks: [Int]?`, default `nil` |
| **Router case** | `CDYahooRouter.teamMatchups(teamKey:weeks:)` |
| **Response type** | [`CDYahooTeamMatchupsResponse`](../Source/CDYahooTeamMatchupsResponse.swift) → `[CDYahooMatchup]` → `[CDYahooMatchupTeamScore]` |
| **Fixture** | [`TeamMatchups.xml`](../Tests/CDYahooKitTests/Fixtures/TeamMatchups.xml) |

#### Request

```
GET …/fantasy/v2/team/{teamKey}/matchups                       (weeks == nil / empty)
GET …/fantasy/v2/team/{teamKey}/matchups;weeks={w1},{w2},…     (weeks non-empty)
```

| Modifier | Required | Status | Notes |
|----------|----------|--------|-------|
| `{teamKey}` path segment | Yes | 🟢 | Format `{league_key}.t.{team_id}`. Percent-encoded as a path segment. |
| `;weeks={w1},{w2},…` | No | 🟢 | Comma-joined raw integers. Omitted entirely when `weeks` is `nil` or empty → the team's full schedule. |

**Limitation (🟢):** only `;weeks=` is exposed. Yahoo also documents a single `;week=` selector and,
for date-based sports, `;date=` (🔵) — CDYahooKit has no parameter for either.

#### Response — XML element tree

```xml
<fantasy_content xml:lang="en-US" time="1.23">
  <team>
    <team_key>449.l.12345.t.1</team_key>
    <team_id>1</team_id>
    <name>Team Alpha</name>
    <matchups count="2">
      <matchup>
        <week>1</week>
        <week_start>2025-09-04</week_start>
        <week_end>2025-09-08</week_end>
        <status>postevent</status>                <!-- preevent | midevent | postevent (🔵) -->
        <is_playoffs>0</is_playoffs>
        <is_consolation>0</is_consolation>
        <is_tied>0</is_tied>
        <winner_team_key>449.l.12345.t.1</winner_team_key>   <!-- absent on a tie / pre-event -->
        <!-- real API also: is_matchup_recap_available, matchup_recap_url, matchup_recap_title -->
        <teams count="2">
          <team>
            <team_key>449.l.12345.t.1</team_key>
            <name>Team Alpha</name>
            <team_points>
              <coverage_type>week</coverage_type>
              <week>1</week>
              <total>112.5</total>
            </team_points>
            <team_projected_points>
              <coverage_type>week</coverage_type>
              <week>1</week>
              <total>105.0</total>
            </team_projected_points>
            <!-- real API team also: win_probability -->
          </team>
          <team>… Team Beta …</team>
        </teams>
      </matchup>
      <!-- … one <matchup> per week in scope -->
    </matchups>
  </team>
</fantasy_content>
```

#### Element → model mapping

| XML path (from `<fantasy_content>`) | Swift property | Type | Required by decoder | Status |
|---|---|---|---|---|
| `team/team_key` | `CDYahooTeamMatchupsResponse.teamKey` | `String` | Yes → `missingField("team")` | 🟢 · 🔵 |
| `team/matchups/matchup` | `.matchups[]` | `[CDYahooMatchup]` | No (missing → `[]`) | 🟢 · 🟡 |
| `…/matchup/week` | `CDYahooMatchup.week` | `Int` (default `0`) | No | 🟢 · 🔵 |
| `…/matchup/status` | `CDYahooMatchup.status` | `String` (default `""`) | No | 🟢 · 🔵 |
| `…/matchup/week_start` | `CDYahooMatchup.weekStart` | `String?` (`YYYY-MM-DD`) | No | 🟢 · 🔵 |
| `…/matchup/week_end` | `CDYahooMatchup.weekEnd` | `String?` | No | 🟢 · 🔵 |
| `…/matchup/is_playoffs` | `CDYahooMatchup.isPlayoffs` | `Bool?` (`"1"`/`"0"`) | No | 🟢 · 🔵 |
| `…/matchup/is_consolation` | `CDYahooMatchup.isConsolation` | `Bool?` | No | 🟢 · 🔵 |
| `…/matchup/is_tied` | `CDYahooMatchup.isTied` | `Bool?` | No | 🟢 · 🔵 |
| `…/matchup/winner_team_key` | `CDYahooMatchup.winnerTeamKey` | `String?` | No | 🟢 · 🔵 |
| `…/matchup/teams/team` | `CDYahooMatchup.teams[]` | `[CDYahooMatchupTeamScore]` | No (missing → `[]`) | 🟢 · 🔵 |
| `…/team/team_key` | `CDYahooMatchupTeamScore.teamKey` | `String` | Yes → `missingField("team")` | 🟢 · 🔵 |
| `…/team/name` | `CDYahooMatchupTeamScore.name` | `String` | Yes | 🟢 · 🔵 |
| `…/team/team_points/total` | `CDYahooMatchupTeamScore.totalPoints` | `Double?` | No | 🟢 · 🟡 |
| `…/team/team_projected_points/total` | `CDYahooMatchupTeamScore.projectedPoints` | `Double?` | No | 🟢 · 🟡 |

#### Cardinality notes

- `matchups count="N"` — one `<matchup>` per week in scope (all weeks, or just those in `;weeks=`).
- `CDYahooMatchup` and `CDYahooMatchupTeamScore` are **shared with the league [scoreboard](#6-league-scoreboard)**.
  The scoreboard payload omits `week_start` … `winner_team_key` and `team_projected_points`, so
  those properties decode to `nil` there.
- **🟡** The extra `<matchup>` fields (`week_start`, `is_tied`, `winner_team_key`, …) and
  `<team_projected_points>` are asserted only by the hand-authored fixture; the shared element
  names carry over from the scoreboard fixture (also 🟡 on `<team_points>` inner shape).

---

### 12. Team stats

A team's accumulated stat totals for a coverage window — the whole season, or one week — plus the
fantasy points they earned in it.

| | |
|---|---|
| **CDYahooKit method** | `CDYahooFantasyAPIClient.fetchTeamStats(teamKey:coverage:)` — `coverage: CDYahooTeamStatsCoverage`, default `.season` |
| **Router case** | `CDYahooRouter.teamStats(teamKey:coverage:)` |
| **Response type** | [`CDYahooTeamStatsResponse`](../Source/CDYahooTeamStatsResponse.swift) → [`CDYahooTeamStats`](../Source/CDYahooTeamStatsResponse.swift) → `[CDYahooTeamStat]` |
| **Fixture** | [`TeamStats.xml`](../Tests/CDYahooKitTests/Fixtures/TeamStats.xml) |

#### Request

```
GET …/fantasy/v2/team/{teamKey}/stats;type=season                 (coverage == .season)
GET …/fantasy/v2/team/{teamKey}/stats;type=week;week={week}       (coverage == .week(week))
```

| Modifier | Required | Status | Notes |
|----------|----------|--------|-------|
| `{teamKey}` path segment | Yes | 🟢 | Percent-encoded as a path segment. |
| `;type=season` \| `;type=week;week={week}` | Yes | 🟢 | Built from `CDYahooTeamStatsCoverage`: `.season` → `;type=season`; `.week(w)` → `;type=week;week=w` (raw `Int`). CDYahooKit always sends one or the other. |

**Limitation (🟢):** the date-based coverage Yahoo supports for baseball/basketball/hockey
(`;type=date;date=YYYY-MM-DD`, `;type=lastweek`, `;type=lastmonth`) (🔵) is not exposed.

#### Response — XML element tree

```xml
<fantasy_content xml:lang="en-US" time="1.23">
  <team>
    <team_key>449.l.12345.t.1</team_key>
    <team_id>1</team_id>
    <name>Team Alpha</name>
    <team_stats>
      <coverage_type>week</coverage_type>          <!-- season | week -->
      <week>8</week>                                <!-- present when coverage_type = week -->
      <stats>
        <stat>
          <stat_id>4</stat_id>
          <value>312</value>
        </stat>
        <stat>
          <stat_id>78</stat_id>
          <value>-</value>                          <!-- "-" = no value in the window -->
        </stat>
        <!-- … one <stat> per league stat category -->
      </stats>
    </team_stats>
    <team_points>
      <coverage_type>week</coverage_type>
      <week>8</week>
      <total>112.5</total>
    </team_points>
  </team>
</fantasy_content>
```

#### Element → model mapping

| XML path (from `<fantasy_content>`) | Swift property | Type | Required by decoder | Status |
|---|---|---|---|---|
| `team/team_key` | `CDYahooTeamStatsResponse.teamKey` | `String` | Yes → `missingField("team")` | 🟢 · 🔵 |
| `team/team_stats/coverage_type` | `CDYahooTeamStats.coverageType` | `String?` | No | 🟢 · 🔵 |
| `team/team_stats/week` | `CDYahooTeamStats.week` | `Int?` | No | 🟢 · 🔵 |
| `team/team_stats/stats/stat` | `CDYahooTeamStats.stats[]` | `[CDYahooTeamStat]` | No (missing → `[]`) | 🟢 · 🟡 |
| `…/stat/stat_id` | `CDYahooTeamStat.statId` | `Int` | Yes → `missingField("stat")` | 🟢 · 🔵 |
| `…/stat/value` | `CDYahooTeamStat.value` | `String` | Yes | 🟢 · 🔵 |
| `team/team_points/total` | `CDYahooTeamStats.totalPoints` | `Double?` | No | 🟢 · 🟡 |

#### Cardinality notes

- `team_stats` is a single element; `team_stats/stats` wraps zero or more `<stat>`. A stats
  response for a league that hasn't played still decodes, with `stats == []`.
- **`value` is kept as a `String`.** Yahoo emits `-` for a stat with no value in the window, and
  emits fractional stats in the leading-dot form (`.5`) — both lossy to round-trip through a
  `Double`. Callers that need a number parse `value` themselves.
- `CDYahooTeamStat.statId` joins to the league [settings](#8-league-settings)'
  `CDYahooStatCategory` (stat name) and `CDYahooStatModifier` (point value).
- **🟡** The `<team_stats>` / `<team_points>` nesting and the `stats`-wrapper shape are asserted
  only by the hand-authored fixture. Real responses also carry `<coverage_type>`/`<week>` on
  `<team_points>` (CDYahooKit reads only `team_points/total`).

---

## Verification summary

| # | Resource | Request URI & params | Response element tree |
|---|----------|----------------------|-----------------------|
| 1 | User's games & leagues | 🟢 code · 🔵 reference | 🟢 decoder paths · 🟡 element names (`game_key`, `name`, `league/name`) |
| 2 | League | 🟢 · 🔵 | 🟢 decoder paths · 🔵 element names · large unmodeled field set |
| 3 | League standings | 🟢 · 🔵 | 🟢 decoder paths · 🔵 elements · 🟡 `<league><name>` echo, `<streak>` unmodeled |
| 4 | Team roster | 🟢 (`;week=` only; no `;date=`) · 🔵 | 🟢 decoder paths · 🔵 elements · 🟡 `eligible_positions`, rich `name` unmodeled |
| 5 | League players | 🟢 (`start` only) · 🔵 | 🟢 decoder paths · 🟡 `<players>` nesting, `ownership` + pagination unmodeled |
| 6 | League scoreboard | 🟢 · 🔵 | 🟢 decoder paths · 🔵 elements · 🟡 `<team_points>` inner shape |
| 7 | League transactions | 🟢 (no filters) · 🔵 | 🟢 decoder paths · 🔵 elements · 🟡 **trade = two `<transaction_data>` per player, only first read** |
| 8 | League settings | 🟢 (no modifiers) · 🔵 | 🟢 decoder paths · 🔵 elements · 🟡 `settings` nesting, parallel stat lists, large unmodeled field set |
| 9 | League draft results | 🟢 (no modifiers) · 🔵 | 🟢 decoder paths · 🔵 elements · 🟡 `<draft_results>` nesting, `cost`-only-on-auction |
| 10 | Team draft results | 🟢 (no modifiers) · 🔵 | 🟢 decoder paths · 🔵 elements · 🟡 `<draft_results>` nesting, `<name>` echo unmodeled |
| 11 | Team matchups | 🟢 (`;weeks=` only) · 🔵 | 🟢 decoder paths · 🔵 elements · 🟡 shared `<matchup>` shape, extra outcome fields + `team_projected_points` |
| 12 | Team stats | 🟢 (`;type=season`/`;type=week`) · 🔵 | 🟢 decoder paths · 🔵 elements · 🟡 `<team_stats>` nesting, `value` as `String` for `-` / leading-dot |

**What is solidly verified:** every request URI, path modifier, and parameter CDYahooKit sends
(read straight from `CDYahooRouter`), and every XML path each `init(node:)` decoder reads (read
straight from `Source/`). **What is inferred:** the exact element names and nesting inside the
fixtures, and the full set of elements Yahoo returns but CDYahooKit ignores. No response in this
table has been checked against output captured from a live Yahoo Developer Network account.

---

## Revisiting with live API access

When a real Yahoo Developer Network account is available, capture one real response per resource
and reconcile it with this document. Specifically confirm:

1. **User games** — is the `<guid>` the only extra element under `<user>`? Do game / league
   summary elements match (`game_key`, `code`, `season`, `league/league_key`, …)?
2. **League** — which of the large real metadata set (`draft_status`, `start_week`, `end_week`,
   `start_date`, `end_date`, `is_finished`, `league_type`, `num_playoff_teams`, …) is worth
   adding to `CDYahooLeague`.
3. **Standings** — does the standings response echo `<league><name>`? Confirm `<streak>`,
   `playoff_seed`, and whether `percentage` is always the leading-dot form. Decide whether
   `CDYahooTeamStanding` should carry `streak` / `playoffSeed` / manager info.
4. **Roster** — confirm `<selected_position>` sub-elements (`coverage_type`, `week`, `is_flex`),
   the `<name>` sub-element set, `eligible_positions`, and the real `status` code vocabulary.
5. **League players** — confirm `<players>` is nested directly under `<league>`, whether the
   collection element carries pagination metadata, and the `<ownership>` shape (candidate for a
   new `CDYahooPlayerOwnership` model).
6. **Scoreboard** — confirm `<team_points>` really wraps `coverage_type` + `week` + `total`, and
   whether `<matchup>` carries `week_start` / `week_end` / `winner_team_key` worth modeling.
7. **Transactions** — **capture a real trade** and confirm the two-`<transaction_data>`-per-player
   shape, then fix `CDYahooTransactionPlayer.init(node:)` to read both moves. Confirm `timestamp`
   and `faab_bid`.
8. **Settings** — confirm `<settings>` is nested under `<league>`, the element names for each
   modeled rule, and that `stat_categories` / `stat_modifiers` are `stats`-wrapped parallel lists
   joined on `stat_id`. Decide which of the large unmodeled field set (draft config, `max_teams`,
   `player_pool`, `has_playoff_consolation_games`, …) is worth adding to `CDYahooLeagueSettings`.
9. **Draft results** — confirm `<draft_results>` nests directly under `<league>` / `<team>`, the
   `<draft_result>` sub-element names (`pick`, `round`, `cost`, `team_key`, `player_key`), that
   `cost` appears only for auction drafts, and whether a real response carries anything else worth
   modeling (a `<players>` expansion when `;out=` is used, timestamps). Same `draftresults`
   sub-resource for both scopes.
10. **Team matchups** — confirm `<matchups>` nests directly under `<team>`, the `<matchup>`
    sub-element names (`week_start`, `week_end`, `is_playoffs`, `is_consolation`, `is_tied`,
    `winner_team_key`), that `<team_projected_points>` sits beside `<team_points>` inside each
    matchup `<team>`, and whether the `;weeks=` list (vs. a single `;week=`) is the right filter.
    Reconcile the shared `CDYahooMatchup` shape against both this and the scoreboard response.
11. **Team stats** — confirm `<team_stats>` (with `<coverage_type>` / `<week>`) and the sibling
    `<team_points>` nest directly under `<team>`, that `stats` wraps the `<stat>` list, the
    `;type=season` / `;type=week;week=` parameter names, and the real `value` vocabulary (whether
    `-` and leading-dot fractions both occur — they drive the `String` typing). Decide whether
    date-based coverage (`;type=date`, `;type=lastweek`) is worth exposing.

Then: regenerate the fixtures in
[`Tests/CDYahooKitTests/Fixtures/`](../Tests/CDYahooKitTests/Fixtures/) from the captured
responses, update the mapping tables above (promoting 🟡 → 🔵/🟢), and drop the hand-authored
caveat from this file, [`ARCHITECTURE.md`](ARCHITECTURE.md), and `CLAUDE.md`.

## Further reading

- [ARCHITECTURE.md](ARCHITECTURE.md) — request pipeline, XML tree parser, OAuth 2.0 + PKCE
- [Usage.md](Usage.md) — task-oriented usage guide
- [Yahoo Fantasy Sports API guide](https://developer.yahoo.com/fantasysports/guide/)
