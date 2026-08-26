# Architecture

```
CDYahooFantasyAPIClient (@MainActor)
  ├─ CDYahooOAuthClient        — OAuth 2.0 + PKCE, Keychain-backed tokens
  ├─ CDYahooRouter              — enum → URLRequest (fantasy/v2/* paths)
  └─ CDYahooURLSession
        ├─ sends the request (cache/retry/adapters/monitors)
        ├─ CDYahooXMLTreeBuilder — parses response Data into a CDYahooXMLNode tree
        └─ hands the root node to the response type's init(node:)
```

## Why XML, not `format=json`

The Fantasy Sports API is XML-native. Its `format=json` parameter exists but produces
inconsistent shapes (single items vs. arrays render differently depending on cardinality), and
any write request must be XML regardless of the read format. CDYahooKit treats XML as the
source of truth end to end via `CDYahooXMLNode`/`CDYahooXMLTreeBuilder`/`CDYahooXMLDecodable` —
one shared parsing engine, with each response model implementing a thin `init(node:)` instead
of a bespoke `XMLParser` delegate.

## Why OAuth 2.0, not CDOAuth1Kit

The Fantasy Sports API requires OAuth 2.0; OAuth 1.0a is no longer usable for new API access.
`CDYahooAuthSession` is modeled directly on CDOAuth1Kit's `CDOAuth1AuthSession` (same
`ASWebAuthenticationSession` wrapper shape), but carries an OAuth 2.0 authorization code instead
of an OAuth 1.0a verifier, and `CDYahooOAuthClient` owns PKCE and silent token refresh, which
OAuth 1.0a has no equivalent of.
