# Getting Started

Register an app, then authenticate and fetch data.

## Registering Your App

Create an app at the [Yahoo Developer Network](https://developer.yahoo.com/apps/), request
Fantasy Sports read access, and note your Client ID, Client Secret, and redirect URI (a custom
URL scheme, e.g. `myapp://callback`).

## Authenticating

```swift
import CDYahooKit

let client = CDYahooFantasyAPIClient(clientId: "...", clientSecret: "...", redirectUrl: "myapp://callback")

let verifier = CDYahooPKCE.makeCodeVerifier()
let challenge = CDYahooPKCE.codeChallenge(for: verifier)
let state = UUID().uuidString
let authURL = try await client.oAuthClient.authorizationURL(codeChallenge: challenge, state: state)

let callback = try await CDYahooAuthSession(presentationAnchor: view.window!)
    .authorize(authorizationURL: authURL, callbackScheme: "myapp")
let code = try CDYahooAuthSession.extractCode(from: callback, expectedState: state)
try await client.oAuthClient.authorize(withCode: code, codeVerifier: verifier)
```

## Fetching Data

```swift
let games = try await client.fetchUserGames()
let leagueKey = games.games.first?.leagues.first?.leagueKey

if let leagueKey {
    let standings = try await client.fetchLeagueStandings(leagueKey: leagueKey)
    for team in standings.teams {
        print(team.name, team.rank ?? 0)
    }
}
```
