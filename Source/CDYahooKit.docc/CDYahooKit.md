# ``CDYahooKit``

A Swift wrapper for the Yahoo Fantasy Sports API, with Sign In With Yahoo (OAuth 2.0 / PKCE)
for authentication.

## Overview

CDYahooKit covers the Yahoo Fantasy Sports API's read-only endpoints — a user's games and
leagues, league metadata, league settings, standings, team rosters, the league player pool, the
weekly scoreboard, league transactions, draft results, a team's matchups and stat totals, and a
game's rule metadata — plus the OAuth 2.0 handshake needed to call them.

Yahoo Fantasy Sports API responses are XML, not JSON; CDYahooKit parses them directly, via an
internal XML tree parser, rather than going through Yahoo's `format=json` parameter, whose output
is known to be inconsistent.

## Topics

### Getting Started

- <doc:GettingStarted>

### Fantasy Sports API

- ``CDYahooFantasyAPIClient``
- ``CDYahooGame``
- ``CDYahooLeague``
- ``CDYahooLeagueSettings``
- ``CDYahooTeamStanding``
- ``CDYahooPlayer``
- ``CDYahooMatchup``
- ``CDYahooTransaction``
- ``CDYahooDraftResult``
- ``CDYahooTeamStats``
- ``CDYahooGameStatCategory``
- ``CDYahooPositionType``
- ``CDYahooGameRosterPosition``
- ``CDYahooGameWeek``

### Authentication

- ``CDYahooOAuthClient``
- ``CDYahooAuthSession``
- ``CDYahooPKCE``

### Errors

- ``CDYahooKitError``
