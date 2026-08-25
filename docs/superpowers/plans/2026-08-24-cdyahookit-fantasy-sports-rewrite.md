# CDYahooKit Fantasy Sports Rewrite Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Replace the stubbed-out Objective-C/CocoaPods CDYahooKit with a modern Swift Package Manager framework that wraps the Yahoo Fantasy Sports API (OAuth 2.0 + PKCE for Sign In With Yahoo, XML-native responses), read-only for v1.

**Architecture:** `CDYahooFantasyAPIClient` (`@MainActor`) → `CDYahooRouter` (enum → `URLRequest`) → `CDYahooURLSession` (network + cache/retry) → `CDYahooXMLTreeBuilder` (parses response `Data` into a `CDYahooXMLNode` tree) → per-resource `init(node:)` builds typed models. Auth is a separate `CDYahooOAuthClient` (Keychain-backed token storage, PKCE, silent refresh) plus `CDYahooAuthSession` (an `ASWebAuthenticationSession` wrapper modeled on CDOAuth1Kit's `CDOAuth1AuthSession`).

**Tech Stack:** Swift 6, Swift Package Manager, Foundation (`XMLParser`, `URLSession`, `Security`/Keychain, `CryptoKit`), `AuthenticationServices` (`ASWebAuthenticationSession`), Swift Testing (`import Testing`, not XCTest — matches CDUntappdKit/CDYelpFusionKit).

**Spec:** `docs/superpowers/specs/2026-08-24-cdyahookit-fantasy-sports-rewrite-design.md`

## Global Constraints

- Platforms: iOS 15+, macOS 12+, tvOS 15+, watchOS 8+, visionOS 1+ (matches CDUntappdKit/CDYelpFusionKit exactly).
- `swift-tools-version:6.0`, `swiftLanguageModes: [.v6]`.
- No external dependencies beyond `swift-docc-plugin` (dev-only) — same "zero dependency" philosophy as all three sibling kits.
- v1 is read-only. No POST/PUT/write endpoints (roster moves, waiver claims, trades) in this plan.
- Scope is Yahoo Fantasy Sports API + Sign In With Yahoo only — nothing else, per the API audit in the spec.
- Auth is OAuth 2.0 + PKCE — never OAuth 1.0a, never a dependency on CDOAuth1Kit.
- Fantasy Sports API responses are parsed as XML (`CDYahooXMLNode` tree), not via `format=json`.
- Tests use Swift Testing (`@Test`, `#expect`, `#require`), not XCTest, matching sibling kits' convention.
- Every public type/method gets a `///` doc comment (DocC convention already established by all three sibling kits) — but no comments on internal logic beyond what the sibling kits' own code shows (explain non-obvious *why*, not *what*).

---

## Task 1: Remove legacy Pods project; bootstrap SPM package

**Files:**
- Delete: `CDYahooKit.podspec`, `CDYahooKit/Classes/` (entire directory), `_Pods.xcodeproj` (symlink), `.travis.yml`
- Create: `Package.swift`
- Create: `Source/CDYahooKit.swift`
- Create: `Source/CDYahooConstants.swift`
- Create: `Source/CDYahooKitError.swift`
- Test: `Tests/CDYahooKitTests/CDYahooKitErrorTests.swift`

**Interfaces:**
- Produces: `CDYahooKitBundleIdentifier: String` (module-level constant), `enum CDYahooConstants` with `fantasyBaseURL`, `oauthAuthorizeURL`, `oauthTokenURL` static `String`s, `public enum CDYahooKitError: Error, LocalizedError` with cases `invalidCredentials(String)`, `invalidRequest(underlying: any Error)`, `xmlParsingFailed(underlying: any Error)`, `responseDecodingFailed(underlying: any Error)`, `apiError(String)`, `authorizationCancelled`.

- [ ] **Step 1: Remove the legacy CocoaPods project**

```bash
git rm CDYahooKit.podspec .travis.yml _Pods.xcodeproj
git rm -r "CDYahooKit/Classes"
```

- [ ] **Step 2: Create `Package.swift`**

```swift
// swift-tools-version:6.0
//
//  Package.swift
//  CDYahooKit
//
//  Copyright (c) 2016-2026 Christopher de Haan <contact@christopherdehaan.me>
//

import PackageDescription

let package = Package(
    name: "CDYahooKit",
    platforms: [.iOS(.v15), .macOS(.v12), .tvOS(.v15), .watchOS(.v8), .visionOS(.v1)],
    products: [
        .library(name: "CDYahooKit", targets: ["CDYahooKit"]),
        .library(name: "CDYahooKitDynamic", type: .dynamic, targets: ["CDYahooKit"])
    ],
    targets: [
        .target(name: "CDYahooKit",
                path: "Source",
                swiftSettings: [.enableUpcomingFeature("ExistentialAny")]),
        .testTarget(name: "CDYahooKitTests",
                    dependencies: ["CDYahooKit"],
                    path: "Tests/CDYahooKitTests")
    ],
    swiftLanguageModes: [.v6]
)
```

- [ ] **Step 3: Create `Source/CDYahooKit.swift`**

```swift
//
//  CDYahooKit.swift
//  CDYahooKit
//
//  Copyright (c) 2016-2026 Christopher de Haan <contact@christopherdehaan.me>
//

import Foundation

let CDYahooKitBundleIdentifier = "me.christopherdehaan.CDYahooKit"
```

- [ ] **Step 4: Create `Source/CDYahooConstants.swift`**

```swift
//
//  CDYahooConstants.swift
//  CDYahooKit
//

import Foundation

enum CDYahooConstants {
    static let fantasyBaseURL = "https://fantasysports.yahooapis.com/fantasy/v2/"
    static let oauthAuthorizeURL = "https://api.login.yahoo.com/oauth2/request_auth"
    static let oauthTokenURL = "https://api.login.yahoo.com/oauth2/get_token"
}
```

- [ ] **Step 5: Write `Source/CDYahooKitError.swift`**

```swift
//
//  CDYahooKitError.swift
//  CDYahooKit
//

import Foundation

/// Errors thrown by CDYahooKit's OAuth and Fantasy Sports API clients.
///
/// `@unchecked Sendable` because the `underlying: any Error` associated values aren't verifiably
/// `Sendable` at compile time — `any Error` erases the concrete type. In practice every error
/// stored here (`URLError`, `DecodingError`, `CDYahooXMLDecodingError`) is safe to share across
/// isolation domains, mirroring `CDYelpRouter`'s identical rationale.
public enum CDYahooKitError: Error, LocalizedError, @unchecked Sendable {
    case invalidCredentials(String)
    case invalidRequest(underlying: any Error)
    case xmlParsingFailed(underlying: any Error)
    case responseDecodingFailed(underlying: any Error)
    case apiError(String)
    case authorizationCancelled

    public var errorDescription: String? {
        switch self {
        case let .invalidCredentials(message):
            message
        case let .invalidRequest(underlying):
            "Invalid request: \(underlying.localizedDescription)"
        case let .xmlParsingFailed(underlying):
            "Failed to parse Yahoo Fantasy API XML: \(underlying.localizedDescription)"
        case let .responseDecodingFailed(underlying):
            "Failed to decode Yahoo response: \(underlying.localizedDescription)"
        case let .apiError(message):
            message
        case .authorizationCancelled:
            "The user cancelled the Sign In With Yahoo authorization flow."
        }
    }
}
```

- [ ] **Step 6: Write the failing test**

```swift
//
//  CDYahooKitErrorTests.swift
//  CDYahooKitTests
//

import Testing
@testable import CDYahooKit

@Suite("CDYahooKitError")
struct CDYahooKitErrorTests {

    @Test("apiError carries its message as the error description")
    func apiErrorDescription() {
        let error = CDYahooKitError.apiError("League not found")
        #expect(error.errorDescription == "League not found")
    }

    @Test("authorizationCancelled has a fixed description")
    func authorizationCancelledDescription() {
        let error = CDYahooKitError.authorizationCancelled
        #expect(error.errorDescription == "The user cancelled the Sign In With Yahoo authorization flow.")
    }
}
```

- [ ] **Step 7: Run the tests**

Run: `swift test --filter CDYahooKitErrorTests`
Expected: PASS (this is the first test in the package — a pass here proves `Package.swift`, `Source/`, and `Tests/` are wired correctly)

- [ ] **Step 8: Commit**

```bash
git add -A
git commit -m "chore: bootstrap SPM package, remove legacy CocoaPods project"
```

---

## Task 2: CI workflow and lint/format configuration

**Files:**
- Create: `.github/workflows/ci.yml`
- Create: `.swiftlint.yml`
- Create: `.swiftformat`
- Create: `.swiftformat-version`
- Create: `.gitignore`

**Interfaces:**
- Consumes: the `CDYahooKit` SPM target from Task 1.
- Produces: nothing consumed by later tasks — this is tooling only.

- [ ] **Step 1: Create `.gitignore`**

```
# Mac OS X
.DS_Store

# Xcode
build/
DerivedData
*.pbxuser
!default.pbxuser
*.mode1v3
!default.mode1v3
*.mode2v3
!default.mode2v3
*.perspectivev3
!default.perspectivev3
xcuserdata
*.xccheckout
*.moved-aside
*.xcuserstate
*.xcscmblueprint
*.hmap
*.ipa
timeline.xctimeline
playground.xcworkspace

# Swift Package Manager
.build/

# Jazzy documentation
docs/undocumented.json

# Example app secrets
Example/Secrets.xcconfig
```

- [ ] **Step 2: Create `.swiftlint.yml`**

```yaml
included:
  - Source
  - Example/Source

file_length: 300
function_body_length: 60
identifier_name:
  excluded:
    - id
    - to
    - url
line_length:
  error: 200
  ignores_comments: true
  ignores_function_declarations: true
  warning: 149
type_body_length: 200
```

- [ ] **Step 3: Create `.swiftformat-version`**

```
0.62.1
```

- [ ] **Step 4: Create `.swiftformat`**

```
# Swift language version target
--swiftversion 6.0

# Indentation: 4 spaces, no tabs
--indent 4
--tabwidth 4
--smarttabs enabled
--indentcase false

# Line length — matches the warning threshold in .swiftlint.yml
--maxwidth 149

# Line endings
--linebreaks lf

# Trailing syntax
--commas inline
--semicolons never
--stripunusedargs closure-only

# Argument wrapping (disabled to prevent code expansion)
--wraparguments preserve
--wrapparameters preserve
--wrapcollections preserve

# Import grouping
--importgrouping testable-last

# File headers: leave existing MIT copyright blocks untouched
--header ignore

# Paths to exclude from formatting
--exclude .build,Pods,docs,Package.swift

# Rules disabled to preserve existing codebase conventions
--disable blankLinesAtStartOfScope,blankLinesAtEndOfScope,blankLineAfterImports,blankLinesBetweenScopes,extensionAccessControl,redundantSelf,redundantType,redundantInternal,wrap,wrapMultilineStatementBraces,wrapPropertyBodies
```

- [ ] **Step 5: Create `.github/workflows/ci.yml`**

SPM-only CI for now (build + test + lint + format). The multi-platform `xcodebuild` matrix (iOS/macOS/tvOS/watchOS/visionOS/Catalyst schemes, matching CDUntappdKit's CI) is added in Task 23, once the Xcode project/workspace and per-platform schemes exist from Task 20 — referencing scheme names that don't exist yet would make this workflow fail immediately.

```yaml
name: "CDYahooKit CI"

on:
  push:
    branches:
      - master
    paths:
      - ".github/workflows/**"
      - "Package.swift"
      - "Source/**"
      - "Tests/**"
  pull_request:
    paths:
      - ".github/workflows/**"
      - "Package.swift"
      - "Source/**"
      - "Tests/**"

concurrency:
  group: ${{ github.ref_name }}
  cancel-in-progress: true

jobs:
  SPM:
    name: Test with SPM
    runs-on: macos-15
    timeout-minutes: 10
    steps:
      - uses: actions/checkout@v4
      - name: Select Xcode
        run: sudo xcode-select -s /Applications/Xcode_16.4.app/Contents/Developer
      - name: Install xcbeautify
        run: brew install xcbeautify
      - name: swift test
        run: set -o pipefail && swift test -c debug 2>&1 | xcbeautify --renderer github-actions

  swiftlint:
    name: SwiftLint
    runs-on: macos-15
    timeout-minutes: 10
    steps:
      - uses: actions/checkout@v4
      - name: Install SwiftLint
        run: brew install swiftlint
      - name: Lint
        run: swiftlint lint --strict

  swiftformat:
    name: SwiftFormat
    runs-on: macos-15
    timeout-minutes: 10
    steps:
      - uses: actions/checkout@v4
      - name: Install SwiftFormat
        run: |
          brew update
          brew upgrade swiftformat || brew install swiftformat
      - name: Verify pinned SwiftFormat version
        run: |
          installed="$(swiftformat --version)"
          pinned="$(cat .swiftformat-version)"
          if [ "$installed" != "$pinned" ]; then
            echo "::error::Installed SwiftFormat $installed does not match the pinned version $pinned in .swiftformat-version."
            exit 1
          fi
      - name: Check formatting
        run: swiftformat Source Tests --lint
```

- [ ] **Step 6: Verify locally**

Run: `swift build && swift test`
Expected: both succeed (same commands the `SPM` CI job runs)

Run: `swiftformat Source Tests --lint` (skip if `swiftformat` isn't installed locally; CI will catch it)
Expected: no violations

- [ ] **Step 7: Commit**

```bash
git add .gitignore .swiftlint.yml .swiftformat .swiftformat-version .github/workflows/ci.yml
git commit -m "chore: add SPM-based CI workflow and lint/format configuration"
```

---

## Task 3: `CDYahooXMLNode` tree type

**Files:**
- Create: `Source/CDYahooXMLNode.swift`
- Test: `Tests/CDYahooKitTests/CDYahooXMLNodeTests.swift`

**Interfaces:**
- Produces: `struct CDYahooXMLNode { let name: String; var attributes: [String: String]; var children: [CDYahooXMLNode]; var text: String }` with methods `child(_ name: String) -> CDYahooXMLNode?`, `children(_ name: String) -> [CDYahooXMLNode]`, `text(_ name: String) -> String?`, `int(_ name: String) -> Int?`. Also `struct CDYahooXMLDecodingError: Error, LocalizedError` with `static func missingField(_ field: String) -> CDYahooXMLDecodingError`.

- [ ] **Step 1: Write the failing test**

```swift
//
//  CDYahooXMLNodeTests.swift
//  CDYahooKitTests
//

import Testing
@testable import CDYahooKit

@Suite("CDYahooXMLNode")
struct CDYahooXMLNodeTests {

    @Test("child(_:) finds the first matching direct child")
    func childFindsFirstMatch() {
        let node = CDYahooXMLNode(name: "league", children: [
            CDYahooXMLNode(name: "name", text: "My League"),
            CDYahooXMLNode(name: "name", text: "Ignored Duplicate")
        ])
        #expect(node.child("name")?.text == "My League")
    }

    @Test("children(_:) returns every matching direct child, in order")
    func childrenReturnsAllMatches() {
        let node = CDYahooXMLNode(name: "teams", children: [
            CDYahooXMLNode(name: "team", text: "1"),
            CDYahooXMLNode(name: "team", text: "2"),
            CDYahooXMLNode(name: "other", text: "3")
        ])
        #expect(node.children("team").map(\.text) == ["1", "2"])
    }

    @Test("text(_:) returns nil for an empty or self-closing element")
    func textReturnsNilForEmptyElement() {
        let node = CDYahooXMLNode(name: "player", children: [
            CDYahooXMLNode(name: "status", text: "")
        ])
        #expect(node.text("status") == nil)
    }

    @Test("int(_:) parses a numeric child's text")
    func intParsesNumericText() {
        let node = CDYahooXMLNode(name: "league", children: [
            CDYahooXMLNode(name: "num_teams", text: "10")
        ])
        #expect(node.int("num_teams") == 10)
    }

    @Test("int(_:) returns nil when the child is missing")
    func intReturnsNilWhenMissing() {
        let node = CDYahooXMLNode(name: "league", children: [])
        #expect(node.int("num_teams") == nil)
    }
}
```

- [ ] **Step 2: Run the test to verify it fails**

Run: `swift test --filter CDYahooXMLNodeTests`
Expected: FAIL — `CDYahooXMLNode` does not exist

- [ ] **Step 3: Write the implementation**

```swift
//
//  CDYahooXMLNode.swift
//  CDYahooKit
//

import Foundation

/// An in-memory tree node built from a Yahoo Fantasy Sports API XML response.
///
/// Every response model implements `init(node:)` against this tree instead of `Codable`'s
/// `init(from:)`, since Fantasy Sports API responses are XML, not JSON — see the "XML Parsing"
/// section of the design spec for why a shared tree beats a bespoke `XMLParser` delegate per
/// resource type.
struct CDYahooXMLNode {
    let name: String
    var attributes: [String: String]
    var children: [CDYahooXMLNode]
    var text: String

    init(name: String, attributes: [String: String] = [:], children: [CDYahooXMLNode] = [], text: String = "") {
        self.name = name
        self.attributes = attributes
        self.children = children
        self.text = text
    }

    /// The first direct child element named `name`, if any.
    func child(_ name: String) -> CDYahooXMLNode? {
        children.first { $0.name == name }
    }

    /// Every direct child element named `name`, in document order.
    func children(_ name: String) -> [CDYahooXMLNode] {
        children.filter { $0.name == name }
    }

    /// The trimmed text content of the first direct child named `name`, or `nil` if the child
    /// is missing, self-closing, or empty — Yahoo represents "no value" both ways depending on
    /// the field, so callers shouldn't have to distinguish them.
    func text(_ name: String) -> String? {
        guard let value = child(name)?.text, !value.isEmpty else { return nil }
        return value
    }

    /// `text(name)` parsed as an `Int`, or `nil` if missing or non-numeric.
    func int(_ name: String) -> Int? {
        text(name).flatMap(Int.init)
    }
}

/// Thrown by a response model's `init(node:)` when a required XML field is missing.
struct CDYahooXMLDecodingError: Error, LocalizedError {
    let missingField: String

    static func missingField(_ field: String) -> CDYahooXMLDecodingError {
        CDYahooXMLDecodingError(missingField: field)
    }

    var errorDescription: String? {
        "Missing required XML field: \(missingField)"
    }
}
```

- [ ] **Step 4: Run the test to verify it passes**

Run: `swift test --filter CDYahooXMLNodeTests`
Expected: PASS

- [ ] **Step 5: Commit**

```bash
git add Source/CDYahooXMLNode.swift Tests/CDYahooKitTests/CDYahooXMLNodeTests.swift
git commit -m "feat(xml): add CDYahooXMLNode tree type"
```

---

## Task 4: `CDYahooXMLTreeBuilder` and `CDYahooXMLDecodable`

**Files:**
- Create: `Source/CDYahooXMLTreeBuilder.swift`
- Create: `Source/CDYahooXMLDecodable.swift`
- Test: `Tests/CDYahooKitTests/CDYahooXMLTreeBuilderTests.swift`

**Interfaces:**
- Consumes: `CDYahooXMLNode` (Task 3), `CDYahooKitError.xmlParsingFailed` (Task 1).
- Produces: `enum CDYahooXMLTreeBuilder { static func parse(_ data: Data) throws -> CDYahooXMLNode }`, `protocol CDYahooXMLDecodable { init(node: CDYahooXMLNode) throws }`.

- [ ] **Step 1: Write the failing test**

```swift
//
//  CDYahooXMLTreeBuilderTests.swift
//  CDYahooKitTests
//

import Testing
@testable import CDYahooKit

@Suite("CDYahooXMLTreeBuilder")
struct CDYahooXMLTreeBuilderTests {

    @Test("parses nested elements, repeated siblings, attributes, and text content")
    func parsesNestedDocument() throws {
        let xml = """
        <?xml version="1.0" encoding="UTF-8"?>
        <fantasy_content>
            <league>
                <league_key>449.l.12345</league_key>
                <standings>
                    <teams count="2">
                        <team><team_id>1</team_id></team>
                        <team><team_id>2</team_id></team>
                    </teams>
                </standings>
            </league>
        </fantasy_content>
        """
        let root = try CDYahooXMLTreeBuilder.parse(Data(xml.utf8))

        #expect(root.name == "fantasy_content")
        let league = try #require(root.child("league"))
        #expect(league.text("league_key") == "449.l.12345")

        let teamsNode = try #require(league.child("standings")?.child("teams"))
        #expect(teamsNode.attributes["count"] == "2")
        #expect(teamsNode.children("team").map { $0.text("team_id") } == ["1", "2"])
    }

    @Test("self-closing elements produce an empty-text node, not a crash")
    func handlesSelfClosingElements() throws {
        let root = try CDYahooXMLTreeBuilder.parse(Data("<player><status/></player>".utf8))
        #expect(root.text("status") == nil)
    }

    @Test("malformed XML throws xmlParsingFailed")
    func malformedXMLThrows() {
        #expect(throws: CDYahooKitError.self) {
            _ = try CDYahooXMLTreeBuilder.parse(Data("<not><closed>".utf8))
        }
    }
}
```

- [ ] **Step 2: Run the test to verify it fails**

Run: `swift test --filter CDYahooXMLTreeBuilderTests`
Expected: FAIL — `CDYahooXMLTreeBuilder` does not exist

- [ ] **Step 3: Write `Source/CDYahooXMLDecodable.swift`**

```swift
//
//  CDYahooXMLDecodable.swift
//  CDYahooKit
//

/// Conformed to by every Fantasy Sports API response/model type. The XML analog of `Decodable`.
protocol CDYahooXMLDecodable {
    init(node: CDYahooXMLNode) throws
}
```

- [ ] **Step 4: Write `Source/CDYahooXMLTreeBuilder.swift`**

```swift
//
//  CDYahooXMLTreeBuilder.swift
//  CDYahooKit
//

import Foundation

/// Parses a Yahoo Fantasy Sports API XML response into a `CDYahooXMLNode` tree in a single pass.
/// This is the only place `XMLParser`'s delegate callbacks are handled directly — every response
/// model then reads from the resulting tree via `init(node:)` instead of implementing its own
/// SAX delegate.
final class CDYahooXMLTreeBuilder: NSObject, XMLParserDelegate {

    private var stack: [CDYahooXMLNode] = []
    private var root: CDYahooXMLNode?
    private var parseError: (any Error)?

    static func parse(_ data: Data) throws -> CDYahooXMLNode {
        let builder = CDYahooXMLTreeBuilder()
        let parser = XMLParser(data: data)
        parser.delegate = builder
        guard parser.parse() else {
            throw CDYahooKitError.xmlParsingFailed(underlying: builder.parseError ?? parser.parserError ?? URLError(.cannotParseResponse))
        }
        guard let root = builder.root else {
            throw CDYahooKitError.xmlParsingFailed(underlying: URLError(.cannotParseResponse))
        }
        return root
    }

    func parser(_ parser: XMLParser, didStartElement elementName: String, namespaceURI: String?,
                qualifiedName qName: String?, attributes attributeDict: [String: String] = [:]) {
        stack.append(CDYahooXMLNode(name: elementName, attributes: attributeDict))
    }

    func parser(_ parser: XMLParser, foundCharacters string: String) {
        guard !stack.isEmpty else { return }
        stack[stack.count - 1].text += string
    }

    func parser(_ parser: XMLParser, didEndElement elementName: String, namespaceURI: String?, qualifiedName qName: String?) {
        guard var finished = stack.popLast() else { return }
        finished.text = finished.text.trimmingCharacters(in: .whitespacesAndNewlines)
        if stack.isEmpty {
            root = finished
        } else {
            stack[stack.count - 1].children.append(finished)
        }
    }

    func parser(_ parser: XMLParser, parseErrorOccurred parseError: Error) {
        self.parseError = parseError
    }
}
```

- [ ] **Step 5: Run the test to verify it passes**

Run: `swift test --filter CDYahooXMLTreeBuilderTests`
Expected: PASS

- [ ] **Step 6: Commit**

```bash
git add Source/CDYahooXMLTreeBuilder.swift Source/CDYahooXMLDecodable.swift Tests/CDYahooKitTests/CDYahooXMLTreeBuilderTests.swift
git commit -m "feat(xml): add CDYahooXMLTreeBuilder and CDYahooXMLDecodable"
```

---

## Task 5: `CDYahooKeychain`

**Files:**
- Create: `Source/CDYahooKeychain.swift`
- Test: `Tests/CDYahooKitTests/CDYahooKeychainTests.swift`

**Interfaces:**
- Produces: `enum CDYahooKeychain { static func set(_ value: String, forKey key: String) -> Bool; static func string(forKey key: String) -> String?; static func delete(forKey key: String) -> Bool }`, `enum CDYahooDefaults { static let accessToken, refreshToken, tokenExpiry: String }`.

- [ ] **Step 1: Write the failing test**

```swift
//
//  CDYahooKeychainTests.swift
//  CDYahooKitTests
//

import Testing
@testable import CDYahooKit

@Suite("CDYahooKeychain")
struct CDYahooKeychainTests {

    @Test("set then string round-trips a value")
    func setThenStringRoundTrips() {
        let key = "CDYahooKeychainTests.roundTrip"
        defer { CDYahooKeychain.delete(forKey: key) }

        #expect(CDYahooKeychain.set("hello", forKey: key))
        #expect(CDYahooKeychain.string(forKey: key) == "hello")
    }

    @Test("set overwrites a previously stored value")
    func setOverwritesExistingValue() {
        let key = "CDYahooKeychainTests.overwrite"
        defer { CDYahooKeychain.delete(forKey: key) }

        #expect(CDYahooKeychain.set("first", forKey: key))
        #expect(CDYahooKeychain.set("second", forKey: key))
        #expect(CDYahooKeychain.string(forKey: key) == "second")
    }

    @Test("string returns nil for a key that was never set")
    func stringReturnsNilForMissingKey() {
        #expect(CDYahooKeychain.string(forKey: "CDYahooKeychainTests.neverSet") == nil)
    }

    @Test("delete removes a stored value")
    func deleteRemovesValue() {
        let key = "CDYahooKeychainTests.delete"
        #expect(CDYahooKeychain.set("value", forKey: key))
        #expect(CDYahooKeychain.delete(forKey: key))
        #expect(CDYahooKeychain.string(forKey: key) == nil)
    }
}
```

- [ ] **Step 2: Run the test to verify it fails**

Run: `swift test --filter CDYahooKeychainTests`
Expected: FAIL — `CDYahooKeychain` does not exist

- [ ] **Step 3: Write the implementation**

```swift
//
//  CDYahooKeychain.swift
//  CDYahooKit
//

import Foundation

/// Keychain storage for OAuth 2.0 tokens, scoped to a fixed generic-password service name so
/// entries don't collide with any other framework's Keychain usage in the same app.
enum CDYahooKeychain {

    private static let service = "CDYahooKit"

    @discardableResult
    static func set(_ value: String, forKey key: String) -> Bool {
        guard let data = value.data(using: .utf8) else { return false }
        delete(forKey: key)
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: key,
            kSecValueData as String: data
        ]
        return SecItemAdd(query as CFDictionary, nil) == errSecSuccess
    }

    static func string(forKey key: String) -> String? {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: key,
            kSecReturnData as String: true,
            kSecMatchLimit as String: kSecMatchLimitOne
        ]
        var result: AnyObject?
        guard SecItemCopyMatching(query as CFDictionary, &result) == errSecSuccess,
              let data = result as? Data else { return nil }
        return String(data: data, encoding: .utf8)
    }

    @discardableResult
    static func delete(forKey key: String) -> Bool {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: key
        ]
        let status = SecItemDelete(query as CFDictionary)
        return status == errSecSuccess || status == errSecItemNotFound
    }
}

enum CDYahooDefaults {
    static let accessToken = "CDYahooKit.accessToken"
    static let refreshToken = "CDYahooKit.refreshToken"
    static let tokenExpiry = "CDYahooKit.tokenExpiry"
}
```

- [ ] **Step 4: Run the test to verify it passes**

Run: `swift test --filter CDYahooKeychainTests`
Expected: PASS

- [ ] **Step 5: Commit**

```bash
git add Source/CDYahooKeychain.swift Tests/CDYahooKitTests/CDYahooKeychainTests.swift
git commit -m "feat(oauth): add CDYahooKeychain token storage"
```

---

## Task 6: Cache, retry, event monitor, and request adapter types

**Files:**
- Create: `Source/CDYahooCacheConfiguration.swift`
- Create: `Source/CDYahooResponseCache.swift`
- Create: `Source/CDYahooRetryConfiguration.swift`
- Create: `Source/CDYahooEventMonitor.swift`
- Create: `Source/CDYahooRequestAdapter.swift`
- Test: `Tests/CDYahooKitTests/CDYahooResponseCacheTests.swift`

**Interfaces:**
- Produces: `struct CDYahooCacheConfiguration { let isEnabled: Bool; let maximumEntries: Int; let timeToLive: TimeInterval; static let disabled; static func enabled(maximumEntries:timeToLive:) }`, `actor CDYahooResponseCache { init(configuration:); func data(forKey:) -> Data?; func store(_:forKey:) }`, `struct CDYahooRetryConfiguration { let maximumRetryCount: Int; let baseDelay: TimeInterval; static let disabled; static func enabled(maximumRetryCount:baseDelay:) }`, `protocol CDYahooEventMonitor: Sendable { func willSend(_ request: URLRequest); func didReceive(_ response: URLResponse?, data: Data?, error: (any Error)?) }`, `protocol CDYahooRequestAdapter: Sendable { func adapt(_ request: URLRequest) -> URLRequest }`.

- [ ] **Step 1: Write the failing test**

```swift
//
//  CDYahooResponseCacheTests.swift
//  CDYahooKitTests
//

import Foundation
import Testing
@testable import CDYahooKit

@Suite("CDYahooResponseCache")
struct CDYahooResponseCacheTests {

    @Test("disabled configuration never stores or returns data")
    func disabledConfigurationStoresNothing() async {
        let cache = CDYahooResponseCache(configuration: .disabled)
        await cache.store(Data("hello".utf8), forKey: "key")
        #expect(await cache.data(forKey: "key") == nil)
    }

    @Test("enabled configuration round-trips stored data")
    func enabledConfigurationRoundTrips() async {
        let cache = CDYahooResponseCache(configuration: .enabled(maximumEntries: 10, timeToLive: 300))
        await cache.store(Data("hello".utf8), forKey: "key")
        #expect(await cache.data(forKey: "key") == Data("hello".utf8))
    }

    @Test("entries older than the time-to-live are treated as a miss")
    func expiredEntriesAreEvicted() async {
        let cache = CDYahooResponseCache(configuration: .enabled(maximumEntries: 10, timeToLive: 0))
        await cache.store(Data("hello".utf8), forKey: "key")
        try? await Task.sleep(nanoseconds: 10_000_000)
        #expect(await cache.data(forKey: "key") == nil)
    }
}
```

- [ ] **Step 2: Run the test to verify it fails**

Run: `swift test --filter CDYahooResponseCacheTests`
Expected: FAIL — `CDYahooResponseCache` does not exist

- [ ] **Step 3: Write `Source/CDYahooCacheConfiguration.swift`**

```swift
//
//  CDYahooCacheConfiguration.swift
//  CDYahooKit
//

import Foundation

/// Configures `CDYahooURLSession`'s opt-in in-memory response cache, applied to `GET` requests
/// only. Disabled by default.
public struct CDYahooCacheConfiguration: Sendable {
    public let isEnabled: Bool
    public let maximumEntries: Int
    public let timeToLive: TimeInterval

    public static let disabled = CDYahooCacheConfiguration(isEnabled: false, maximumEntries: 0, timeToLive: 0)

    public static func enabled(maximumEntries: Int = 100, timeToLive: TimeInterval = 300) -> CDYahooCacheConfiguration {
        CDYahooCacheConfiguration(isEnabled: true, maximumEntries: maximumEntries, timeToLive: timeToLive)
    }
}
```

- [ ] **Step 4: Write `Source/CDYahooResponseCache.swift`**

```swift
//
//  CDYahooResponseCache.swift
//  CDYahooKit
//

import Foundation

/// An in-memory `GET` response cache. An `actor` so concurrent reads/writes from multiple
/// in-flight requests can't race on the backing dictionary.
actor CDYahooResponseCache {

    private struct Entry {
        let data: Data
        let storedAt: Date
    }

    private var storage: [String: Entry] = [:]
    private let configuration: CDYahooCacheConfiguration

    init(configuration: CDYahooCacheConfiguration) {
        self.configuration = configuration
    }

    func data(forKey key: String) -> Data? {
        guard configuration.isEnabled, let entry = storage[key] else { return nil }
        guard Date().timeIntervalSince(entry.storedAt) < configuration.timeToLive else {
            storage[key] = nil
            return nil
        }
        return entry.data
    }

    func store(_ data: Data, forKey key: String) {
        guard configuration.isEnabled else { return }
        if storage.count >= configuration.maximumEntries {
            storage.removeAll()
        }
        storage[key] = Entry(data: data, storedAt: Date())
    }
}
```

- [ ] **Step 5: Write `Source/CDYahooRetryConfiguration.swift`**

```swift
//
//  CDYahooRetryConfiguration.swift
//  CDYahooKit
//

import Foundation

/// Configures `CDYahooURLSession`'s automatic retry with exponential backoff on transient
/// failures. Disabled by default.
public struct CDYahooRetryConfiguration: Sendable {
    public let maximumRetryCount: Int
    public let baseDelay: TimeInterval

    public static let disabled = CDYahooRetryConfiguration(maximumRetryCount: 0, baseDelay: 0)

    public static func enabled(maximumRetryCount: Int = 3, baseDelay: TimeInterval = 0.5) -> CDYahooRetryConfiguration {
        CDYahooRetryConfiguration(maximumRetryCount: maximumRetryCount, baseDelay: baseDelay)
    }
}
```

- [ ] **Step 6: Write `Source/CDYahooEventMonitor.swift`**

```swift
//
//  CDYahooEventMonitor.swift
//  CDYahooKit
//

import Foundation

/// Observes request/response lifecycle events on every request `CDYahooURLSession` sends.
public protocol CDYahooEventMonitor: Sendable {
    func willSend(_ request: URLRequest)
    func didReceive(_ response: URLResponse?, data: Data?, error: (any Error)?)
}
```

- [ ] **Step 7: Write `Source/CDYahooRequestAdapter.swift`**

```swift
//
//  CDYahooRequestAdapter.swift
//  CDYahooKit
//

import Foundation

/// Mutates each outgoing request before `CDYahooURLSession` sends it. Adapters run in the order
/// they were supplied.
public protocol CDYahooRequestAdapter: Sendable {
    func adapt(_ request: URLRequest) -> URLRequest
}
```

- [ ] **Step 8: Run the test to verify it passes**

Run: `swift test --filter CDYahooResponseCacheTests`
Expected: PASS

- [ ] **Step 9: Commit**

```bash
git add Source/CDYahooCacheConfiguration.swift Source/CDYahooResponseCache.swift Source/CDYahooRetryConfiguration.swift Source/CDYahooEventMonitor.swift Source/CDYahooRequestAdapter.swift Tests/CDYahooKitTests/CDYahooResponseCacheTests.swift
git commit -m "feat(networking): add cache, retry, event monitor, and request adapter types"
```

---

## Task 7: `CDYahooURLSession`

**Files:**
- Create: `Source/CDYahooURLSession.swift`
- Test: `Tests/CDYahooKitTests/CDYahooURLSessionTests.swift`

**Interfaces:**
- Consumes: `CDYahooXMLDecodable`, `CDYahooXMLTreeBuilder.parse(_:)` (Task 4), `CDYahooResponseCache`, `CDYahooCacheConfiguration`, `CDYahooRetryConfiguration`, `CDYahooEventMonitor`, `CDYahooRequestAdapter` (Task 6), `CDYahooKitError` (Task 1).
- Produces: `final class CDYahooURLSession { init(session: URLSession, retryConfiguration: CDYahooRetryConfiguration = .disabled, eventMonitors: [any CDYahooEventMonitor] = [], requestAdapters: [any CDYahooRequestAdapter] = [], cacheConfiguration: CDYahooCacheConfiguration = .disabled); func perform<T: CDYahooXMLDecodable>(_ request: URLRequest) async throws -> T }`.

This task temporarily uses `URLProtocol`-based stubbing written inline (the shared `CDYahooMockURLProtocol` testing helper doesn't exist until Task 8) — a private, file-local `URLProtocol` subclass is fine here since it's deleted once Task 8 supersedes it.

- [ ] **Step 1: Write the failing test**

```swift
//
//  CDYahooURLSessionTests.swift
//  CDYahooKitTests
//

import Foundation
import Testing
@testable import CDYahooKit

private struct StubResponse: CDYahooXMLDecodable, Equatable {
    let value: String
    init(node: CDYahooXMLNode) throws {
        guard let value = node.text("value") else {
            throw CDYahooXMLDecodingError.missingField("value")
        }
        self.value = value
    }
}

/// Minimal inline stub protocol — superseded by `CDYahooMockURLProtocol` (Task 8) for every
/// later test in this suite.
private final class InlineStubProtocol: URLProtocol, @unchecked Sendable {
    nonisolated(unsafe) static var statusCode = 200
    nonisolated(unsafe) static var body = Data()
    nonisolated(unsafe) static var requestCount = 0

    override class func canInit(with request: URLRequest) -> Bool { true }
    override class func canonicalRequest(for request: URLRequest) -> URLRequest { request }
    override func startLoading() {
        Self.requestCount += 1
        let response = HTTPURLResponse(url: request.url!, statusCode: Self.statusCode, httpVersion: "HTTP/1.1", headerFields: nil)!
        client?.urlProtocol(self, didReceive: response, cacheStoragePolicy: .notAllowed)
        client?.urlProtocol(self, didLoad: Self.body)
        client?.urlProtocolDidFinishLoading(self)
    }
    override func stopLoading() {}
}

@Suite("CDYahooURLSession")
struct CDYahooURLSessionTests {

    private func makeSession(retryConfiguration: CDYahooRetryConfiguration = .disabled,
                              cacheConfiguration: CDYahooCacheConfiguration = .disabled) -> CDYahooURLSession {
        let configuration = URLSessionConfiguration.ephemeral
        configuration.protocolClasses = [InlineStubProtocol.self]
        return CDYahooURLSession(session: URLSession(configuration: configuration),
                                  retryConfiguration: retryConfiguration,
                                  cacheConfiguration: cacheConfiguration)
    }

    @Test("decodes a successful XML response into the requested type")
    func decodesSuccessfulResponse() async throws {
        InlineStubProtocol.statusCode = 200
        InlineStubProtocol.body = Data("<root><value>hello</value></root>".utf8)
        let session = makeSession()

        let result: StubResponse = try await session.perform(URLRequest(url: URL(string: "https://example.com/a")!))
        #expect(result.value == "hello")
    }

    @Test("throws for a non-2xx HTTP status")
    func throwsForNon2xxStatus() async {
        InlineStubProtocol.statusCode = 404
        InlineStubProtocol.body = Data()
        let session = makeSession()

        await #expect(throws: CDYahooKitError.self) {
            let _: StubResponse = try await session.perform(URLRequest(url: URL(string: "https://example.com/b")!))
        }
    }

    @Test("retries the configured number of times before giving up")
    func retriesOnFailure() async {
        InlineStubProtocol.statusCode = 500
        InlineStubProtocol.body = Data()
        InlineStubProtocol.requestCount = 0
        let session = makeSession(retryConfiguration: .enabled(maximumRetryCount: 2, baseDelay: 0.01))

        await #expect(throws: CDYahooKitError.self) {
            let _: StubResponse = try await session.perform(URLRequest(url: URL(string: "https://example.com/c")!))
        }
        #expect(InlineStubProtocol.requestCount == 3)
    }

    @Test("throws apiError when the response root is a Yahoo <error> envelope")
    func throwsApiErrorForErrorEnvelope() async throws {
        InlineStubProtocol.statusCode = 200
        InlineStubProtocol.body = Data("<error><description>Invalid league key.</description></error>".utf8)
        let session = makeSession()

        let thrown = try await #require(throws: CDYahooKitError.self) {
            let _: StubResponse = try await session.perform(URLRequest(url: URL(string: "https://example.com/d")!))
        }
        #expect(thrown.errorDescription == "Invalid league key.")
    }
}
```

- [ ] **Step 2: Run the test to verify it fails**

Run: `swift test --filter CDYahooURLSessionTests`
Expected: FAIL — `CDYahooURLSession` does not exist

- [ ] **Step 3: Write the implementation**

```swift
//
//  CDYahooURLSession.swift
//  CDYahooKit
//

import Foundation

/// Sends requests, applies caching/retry/adapters/monitors, and decodes the XML response body
/// into a `CDYahooXMLDecodable` type. Every public client (`CDYahooOAuthClient`,
/// `CDYahooFantasyAPIClient`) is built around one of these.
final class CDYahooURLSession: Sendable {

    private let session: URLSession
    private let cache: CDYahooResponseCache
    private let retryConfiguration: CDYahooRetryConfiguration
    private let eventMonitors: [any CDYahooEventMonitor]
    private let requestAdapters: [any CDYahooRequestAdapter]

    init(session: URLSession,
         retryConfiguration: CDYahooRetryConfiguration = .disabled,
         eventMonitors: [any CDYahooEventMonitor] = [],
         requestAdapters: [any CDYahooRequestAdapter] = [],
         cacheConfiguration: CDYahooCacheConfiguration = .disabled) {
        self.session = session
        self.retryConfiguration = retryConfiguration
        self.eventMonitors = eventMonitors
        self.requestAdapters = requestAdapters
        self.cache = CDYahooResponseCache(configuration: cacheConfiguration)
    }

    func perform<T: CDYahooXMLDecodable>(_ request: URLRequest) async throws -> T {
        var adaptedRequest = request
        for adapter in requestAdapters {
            adaptedRequest = adapter.adapt(adaptedRequest)
        }

        let isCacheable = adaptedRequest.httpMethod == nil || adaptedRequest.httpMethod == "GET"
        let cacheKey = adaptedRequest.url?.absoluteString ?? ""

        if isCacheable, let cachedData = await cache.data(forKey: cacheKey) {
            return try Self.decode(cachedData)
        }

        var attempt = 0
        while true {
            for monitor in eventMonitors { monitor.willSend(adaptedRequest) }
            do {
                let (data, response) = try await session.data(for: adaptedRequest)
                guard let httpResponse = response as? HTTPURLResponse, (200..<300).contains(httpResponse.statusCode) else {
                    throw CDYahooKitError.invalidRequest(underlying: URLError(.badServerResponse))
                }
                for monitor in eventMonitors { monitor.didReceive(response, data: data, error: nil) }
                if isCacheable {
                    await cache.store(data, forKey: cacheKey)
                }
                return try Self.decode(data)
            } catch {
                for monitor in eventMonitors { monitor.didReceive(nil, data: nil, error: error) }
                attempt += 1
                guard attempt <= retryConfiguration.maximumRetryCount else { throw error }
                let delay = retryConfiguration.baseDelay * pow(2.0, Double(attempt - 1))
                try? await Task.sleep(nanoseconds: UInt64(delay * 1_000_000_000))
            }
        }
    }

    /// Parses `data` and decodes it as `T` — unless the root element is Yahoo's `<error>`
    /// envelope, in which case this throws `CDYahooKitError.apiError` with its `<description>`
    /// instead of trying (and failing) to decode it as `T`. Every Fantasy Sports API response
    /// passes through here, so this is the single place that check needs to live.
    private static func decode<T: CDYahooXMLDecodable>(_ data: Data) throws -> T {
        let root = try CDYahooXMLTreeBuilder.parse(data)
        if root.name == "error" {
            throw CDYahooKitError.apiError(root.text("description") ?? "Yahoo Fantasy API returned an error.")
        }
        return try T(node: root)
    }
}
```

- [ ] **Step 4: Run the test to verify it passes**

Run: `swift test --filter CDYahooURLSessionTests`
Expected: PASS

- [ ] **Step 5: Commit**

```bash
git add Source/CDYahooURLSession.swift Tests/CDYahooKitTests/CDYahooURLSessionTests.swift
git commit -m "feat(networking): add CDYahooURLSession"
```

---

## Task 8: `CDYahooKitTesting` product and `CDYahooMockURLProtocol`

**Files:**
- Create: `Source/Testing/CDYahooMockURLProtocol.swift`
- Modify: `Package.swift` — add the `CDYahooKitTesting` library product and target
- Test: `Tests/CDYahooKitTests/CDYahooMockURLProtocolTests.swift`

**Interfaces:**
- Produces: `public final class CDYahooMockURLProtocol: URLProtocol { public struct Stub: Sendable { public init(statusCode: Int = 200, data: Data = Data(), headers: [String: String] = [:], error: (any Error & Sendable)? = nil, delay: TimeInterval = 0) }; public static func stubbing(_ request: URLRequest, with stub: Stub) -> URLRequest; public static func register(stub: Stub, for url: URL); public static func register(stubs: [Stub], for url: URL); public static func requestCount(for url: URL) -> Int; public static func makeSession() -> URLSession }`.

- [ ] **Step 1: Modify `Package.swift`**

Add the testing product/target (add to `products:` and `targets:`, and exclude `Testing/` from the main target):

```swift
    products: [
        .library(name: "CDYahooKit", targets: ["CDYahooKit"]),
        .library(name: "CDYahooKitDynamic", type: .dynamic, targets: ["CDYahooKit"]),
        .library(name: "CDYahooKitTesting", targets: ["CDYahooKitTesting"])
    ],
    targets: [
        .target(name: "CDYahooKit",
                path: "Source",
                exclude: ["Testing"],
                swiftSettings: [.enableUpcomingFeature("ExistentialAny")]),
        .target(name: "CDYahooKitTesting",
                path: "Source/Testing",
                swiftSettings: [.enableUpcomingFeature("ExistentialAny")]),
        .testTarget(name: "CDYahooKitTests",
                    dependencies: ["CDYahooKit", "CDYahooKitTesting"],
                    path: "Tests/CDYahooKitTests")
    ],
```

- [ ] **Step 2: Write the failing test**

```swift
//
//  CDYahooMockURLProtocolTests.swift
//  CDYahooKitTests
//

import Foundation
import Testing
@testable import CDYahooKit
import CDYahooKitTesting

@Suite("CDYahooMockURLProtocol")
struct CDYahooMockURLProtocolTests {

    @Test("register(stub:for:) serves the stub to any request for that URL")
    func registeredStubIsServed() async throws {
        let url = URL(string: "https://example.com/CDYahooMockURLProtocolTests/registered")!
        CDYahooMockURLProtocol.register(stub: .init(statusCode: 200, data: Data("ok".utf8)), for: url)

        let session = CDYahooMockURLProtocol.makeSession()
        let (data, response) = try await session.data(for: URLRequest(url: url))

        #expect((response as? HTTPURLResponse)?.statusCode == 200)
        #expect(data == Data("ok".utf8))
    }

    @Test("register(stubs:for:) serves stubs in order, then repeats the last one")
    func stubSequenceRepeatsLastEntry() async throws {
        let url = URL(string: "https://example.com/CDYahooMockURLProtocolTests/sequence")!
        CDYahooMockURLProtocol.register(stubs: [.init(statusCode: 500), .init(statusCode: 200)], for: url)

        let session = CDYahooMockURLProtocol.makeSession()
        let first = try await session.data(for: URLRequest(url: url))
        let second = try await session.data(for: URLRequest(url: url))
        let third = try await session.data(for: URLRequest(url: url))

        #expect((first.1 as? HTTPURLResponse)?.statusCode == 500)
        #expect((second.1 as? HTTPURLResponse)?.statusCode == 200)
        #expect((third.1 as? HTTPURLResponse)?.statusCode == 200)
        #expect(CDYahooMockURLProtocol.requestCount(for: url) == 3)
    }
}
```

- [ ] **Step 3: Run the test to verify it fails**

Run: `swift test --filter CDYahooMockURLProtocolTests`
Expected: FAIL — `CDYahooMockURLProtocol` / module `CDYahooKitTesting` does not exist

- [ ] **Step 4: Write `Source/Testing/CDYahooMockURLProtocol.swift`**

```swift
//
//  CDYahooMockURLProtocol.swift
//  CDYahooKitTesting
//

import Foundation

/// A `URLProtocol` that intercepts every request and returns a pre-configured response, for
/// testing `CDYahooURLSession` and its callers without making a real network call.
///
/// Two ways to attach a stub: `stubbing(_:with:)` attaches to one specific `URLRequest` instance;
/// `register(stub:for:)` associates a stub with a `URL` in a lock-protected dictionary, for code
/// under test that builds its own `URLRequest` internally (e.g. `CDYahooFantasyAPIClient`'s
/// fetch methods, built via `CDYahooRouter`). Give each registration a distinct `URL` so
/// concurrently-running tests never collide on the same entry.
public final class CDYahooMockURLProtocol: URLProtocol, @unchecked Sendable {

    public struct Stub: Sendable {
        public let statusCode: Int
        public let data: Data
        public let headers: [String: String]
        public let error: (any Error & Sendable)?
        public let delay: TimeInterval

        public init(statusCode: Int = 200, data: Data = Data(), headers: [String: String] = [:],
                    error: (any Error & Sendable)? = nil, delay: TimeInterval = 0) {
            self.statusCode = statusCode
            self.data = data
            self.headers = headers
            self.error = error
            self.delay = delay
        }
    }

    private static let stubPropertyKey = "CDYahooMockURLProtocolStub"
    private static let urlKeyedStubsLock = NSLock()
    private nonisolated(unsafe) static var urlKeyedStubQueues: [URL: [Stub]] = [:]
    private nonisolated(unsafe) static var urlKeyedRequestCounts: [URL: Int] = [:]

    public static func stubbing(_ request: URLRequest, with stub: Stub) -> URLRequest {
        guard let mutableRequest = (request as NSURLRequest).mutableCopy() as? NSMutableURLRequest else {
            return request
        }
        URLProtocol.setProperty(stub, forKey: stubPropertyKey, in: mutableRequest)
        return mutableRequest as URLRequest
    }

    public static func register(stub: Stub, for url: URL) {
        register(stubs: [stub], for: url)
    }

    public static func register(stubs: [Stub], for url: URL) {
        urlKeyedStubsLock.lock()
        defer { urlKeyedStubsLock.unlock() }
        urlKeyedStubQueues[url] = stubs
        urlKeyedRequestCounts[url] = 0
    }

    public static func requestCount(for url: URL) -> Int {
        urlKeyedStubsLock.lock()
        defer { urlKeyedStubsLock.unlock() }
        return urlKeyedRequestCounts[url] ?? 0
    }

    private static func urlKeyedStub(for url: URL?) -> Stub? {
        guard let url else { return nil }
        urlKeyedStubsLock.lock()
        defer { urlKeyedStubsLock.unlock() }
        guard var queue = urlKeyedStubQueues[url], let stub = queue.first else { return nil }
        if queue.count > 1 {
            queue.removeFirst()
            urlKeyedStubQueues[url] = queue
        }
        urlKeyedRequestCounts[url, default: 0] += 1
        return stub
    }

    public static func makeSession() -> URLSession {
        let configuration = URLSessionConfiguration.ephemeral
        configuration.protocolClasses = [CDYahooMockURLProtocol.self]
        return URLSession(configuration: configuration)
    }

    override public static func canInit(with request: URLRequest) -> Bool { true }
    override public static func canonicalRequest(for request: URLRequest) -> URLRequest { request }

    override public func startLoading() {
        guard let stub = (URLProtocol.property(forKey: Self.stubPropertyKey, in: request) as? Stub)
            ?? Self.urlKeyedStub(for: request.url)
        else {
            client?.urlProtocol(self, didFailWithError: URLError(.unknown))
            return
        }
        guard stub.delay > 0 else {
            respond(with: stub)
            return
        }
        DispatchQueue.global().asyncAfter(deadline: .now() + stub.delay) { [weak self] in
            self?.respond(with: stub)
        }
    }

    override public func stopLoading() {}

    private func respond(with stub: Stub) {
        if let error = stub.error {
            client?.urlProtocol(self, didFailWithError: error)
            return
        }
        let response = HTTPURLResponse(
            url: request.url ?? URL(string: "https://fantasysports.yahooapis.com/fantasy/v2/")!,
            statusCode: stub.statusCode,
            httpVersion: "HTTP/1.1",
            headerFields: stub.headers
        )!
        client?.urlProtocol(self, didReceive: response, cacheStoragePolicy: .notAllowed)
        client?.urlProtocol(self, didLoad: stub.data)
        client?.urlProtocolDidFinishLoading(self)
    }
}
```

- [ ] **Step 5: Run the test to verify it passes**

Run: `swift test --filter CDYahooMockURLProtocolTests`
Expected: PASS

- [ ] **Step 6: Commit**

```bash
git add Package.swift Source/Testing/CDYahooMockURLProtocol.swift Tests/CDYahooKitTests/CDYahooMockURLProtocolTests.swift
git commit -m "feat(testing): add CDYahooKitTesting product with mock URLProtocol"
```

---

## Task 9: `CDYahooPKCE`

**Files:**
- Create: `Source/CDYahooPKCE.swift`
- Test: `Tests/CDYahooKitTests/CDYahooPKCETests.swift`

**Interfaces:**
- Produces: `enum CDYahooPKCE { static func makeCodeVerifier() -> String; static func codeChallenge(for verifier: String) -> String }`.

- [ ] **Step 1: Write the failing test**

```swift
//
//  CDYahooPKCETests.swift
//  CDYahooKitTests
//

import Testing
@testable import CDYahooKit

@Suite("CDYahooPKCE")
struct CDYahooPKCETests {

    @Test("makeCodeVerifier produces a 43-character base64url string with no padding")
    func codeVerifierIsWellFormed() {
        let verifier = CDYahooPKCE.makeCodeVerifier()
        #expect(verifier.count == 43)
        #expect(verifier.allSatisfy { $0.isLetter || $0.isNumber || $0 == "-" || $0 == "_" })
    }

    @Test("makeCodeVerifier produces a different value on each call")
    func codeVerifierIsRandom() {
        #expect(CDYahooPKCE.makeCodeVerifier() != CDYahooPKCE.makeCodeVerifier())
    }

    @Test("codeChallenge is deterministic for the same verifier")
    func codeChallengeIsDeterministic() {
        let verifier = "fixed-test-verifier-value"
        #expect(CDYahooPKCE.codeChallenge(for: verifier) == CDYahooPKCE.codeChallenge(for: verifier))
    }

    @Test("codeChallenge is a 43-character base64url string with no padding")
    func codeChallengeIsWellFormed() {
        let challenge = CDYahooPKCE.codeChallenge(for: "fixed-test-verifier-value")
        #expect(challenge.count == 43)
        #expect(challenge.allSatisfy { $0.isLetter || $0.isNumber || $0 == "-" || $0 == "_" })
    }
}
```

- [ ] **Step 2: Run the test to verify it fails**

Run: `swift test --filter CDYahooPKCETests`
Expected: FAIL — `CDYahooPKCE` does not exist

- [ ] **Step 3: Write the implementation**

```swift
//
//  CDYahooPKCE.swift
//  CDYahooKit
//

import Crypto
import Foundation

/// PKCE (RFC 7636) code verifier/challenge generation for the Sign In With Yahoo OAuth 2.0
/// authorization code flow.
enum CDYahooPKCE {

    /// A cryptographically random 32-byte verifier, base64url-encoded (43 characters, no
    /// padding) — within RFC 7636's required 43-128 character range.
    static func makeCodeVerifier() -> String {
        var bytes = [UInt8](repeating: 0, count: 32)
        _ = SecRandomCopyBytes(kSecRandomDefault, bytes.count, &bytes)
        return base64URLEncode(Data(bytes))
    }

    /// The S256 challenge for `verifier`: base64url(SHA256(verifier)).
    static func codeChallenge(for verifier: String) -> String {
        let digest = SHA256.hash(data: Data(verifier.utf8))
        return base64URLEncode(Data(digest))
    }

    private static func base64URLEncode(_ data: Data) -> String {
        data.base64EncodedString()
            .replacingOccurrences(of: "+", with: "-")
            .replacingOccurrences(of: "/", with: "_")
            .replacingOccurrences(of: "=", with: "")
    }
}
```

- [ ] **Step 4: Run the test to verify it passes**

Run: `swift test --filter CDYahooPKCETests`
Expected: PASS

- [ ] **Step 5: Commit**

```bash
git add Source/CDYahooPKCE.swift Tests/CDYahooKitTests/CDYahooPKCETests.swift
git commit -m "feat(oauth): add CDYahooPKCE code verifier/challenge generation"
```

---

## Task 10: `CDYahooOAuthCredential` and `CDYahooOAuthRouter`

**Files:**
- Create: `Source/CDYahooOAuthCredential.swift`
- Create: `Source/CDYahooOAuthRouter.swift`
- Test: `Tests/CDYahooKitTests/CDYahooOAuthRouterTests.swift`

**Interfaces:**
- Consumes: `CDYahooConstants.oauthTokenURL` (Task 1), `CDYahooKitError` (Task 1).
- Produces: `struct CDYahooOAuthCredential: Codable, Sendable { let accessToken: String; let refreshToken: String?; let expiresIn: Int; let tokenType: String; let xoauthYahooGuid: String? }`, `enum CDYahooOAuthRouter { case authorize(code: String, redirectUrl: String, codeVerifier: String); case refresh(refreshToken: String, redirectUrl: String); func asURLRequest(clientId: String, clientSecret: String) throws -> URLRequest }`.

- [ ] **Step 1: Write the failing test**

```swift
//
//  CDYahooOAuthRouterTests.swift
//  CDYahooKitTests
//

import Foundation
import Testing
@testable import CDYahooKit

@Suite("CDYahooOAuthRouter")
struct CDYahooOAuthRouterTests {

    @Test("authorize builds a POST to the token endpoint with Basic auth and a form-encoded body")
    func authorizeBuildsCorrectRequest() throws {
        let request = try CDYahooOAuthRouter.authorize(code: "abc123", redirectUrl: "myapp://callback", codeVerifier: "verifier-value")
            .asURLRequest(clientId: "client-id", clientSecret: "client-secret")

        #expect(request.url?.absoluteString == "https://api.login.yahoo.com/oauth2/get_token")
        #expect(request.httpMethod == "POST")
        #expect(request.value(forHTTPHeaderField: "Content-Type") == "application/x-www-form-urlencoded")

        let expectedCredentials = Data("client-id:client-secret".utf8).base64EncodedString()
        #expect(request.value(forHTTPHeaderField: "Authorization") == "Basic \(expectedCredentials)")

        let bodyString = String(data: try #require(request.httpBody), encoding: .utf8) ?? ""
        #expect(bodyString.contains("grant_type=authorization_code"))
        #expect(bodyString.contains("code=abc123"))
        #expect(bodyString.contains("code_verifier=verifier-value"))
        #expect(bodyString.contains("redirect_uri=myapp://callback"))
    }

    @Test("refresh builds a POST with grant_type=refresh_token")
    func refreshBuildsCorrectRequest() throws {
        let request = try CDYahooOAuthRouter.refresh(refreshToken: "refresh-abc", redirectUrl: "myapp://callback")
            .asURLRequest(clientId: "client-id", clientSecret: "client-secret")

        let bodyString = String(data: try #require(request.httpBody), encoding: .utf8) ?? ""
        #expect(bodyString.contains("grant_type=refresh_token"))
        #expect(bodyString.contains("refresh_token=refresh-abc"))
    }
}
```

(The unused `body`/`expectedCredentials` intermediate in the first test is dead weight from drafting — remove the first `let body = ...` line before committing; only `bodyString` is used.)

- [ ] **Step 2: Run the test to verify it fails**

Run: `swift test --filter CDYahooOAuthRouterTests`
Expected: FAIL — `CDYahooOAuthRouter` does not exist

- [ ] **Step 3: Write `Source/CDYahooOAuthCredential.swift`**

```swift
//
//  CDYahooOAuthCredential.swift
//  CDYahooKit
//

import Foundation

/// The JSON response from Yahoo's OAuth 2.0 token endpoint (`/oauth2/get_token`) — unlike the
/// Fantasy Sports data API, the OAuth token endpoint returns JSON, not XML.
struct CDYahooOAuthCredential: Codable, Sendable {
    let accessToken: String
    let refreshToken: String?
    let expiresIn: Int
    let tokenType: String
    let xoauthYahooGuid: String?

    enum CodingKeys: String, CodingKey {
        case accessToken = "access_token"
        case refreshToken = "refresh_token"
        case expiresIn = "expires_in"
        case tokenType = "token_type"
        case xoauthYahooGuid = "xoauth_yahoo_guid"
    }
}
```

- [ ] **Step 4: Write `Source/CDYahooOAuthRouter.swift`**

```swift
//
//  CDYahooOAuthRouter.swift
//  CDYahooKit
//

import Foundation

/// Builds requests to Yahoo's OAuth 2.0 token endpoint.
enum CDYahooOAuthRouter {
    case authorize(code: String, redirectUrl: String, codeVerifier: String)
    case refresh(refreshToken: String, redirectUrl: String)

    func asURLRequest(clientId: String, clientSecret: String) throws -> URLRequest {
        guard let url = URL(string: CDYahooConstants.oauthTokenURL) else {
            throw CDYahooKitError.invalidRequest(underlying: URLError(.badURL))
        }
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/x-www-form-urlencoded", forHTTPHeaderField: "Content-Type")

        guard let credentialsData = "\(clientId):\(clientSecret)".data(using: .utf8) else {
            throw CDYahooKitError.invalidCredentials("clientId/clientSecret could not be encoded.")
        }
        request.setValue("Basic \(credentialsData.base64EncodedString())", forHTTPHeaderField: "Authorization")

        let params: [String: String]
        switch self {
        case let .authorize(code, redirectUrl, codeVerifier):
            params = ["grant_type": "authorization_code",
                      "redirect_uri": redirectUrl,
                      "code": code,
                      "code_verifier": codeVerifier]
        case let .refresh(refreshToken, redirectUrl):
            params = ["grant_type": "refresh_token",
                      "redirect_uri": redirectUrl,
                      "refresh_token": refreshToken]
        }

        var allowedCharacters = CharacterSet.urlQueryAllowed
        allowedCharacters.remove(charactersIn: "+&=")
        let body = params
            .map { key, value in "\(key)=\(value.addingPercentEncoding(withAllowedCharacters: allowedCharacters) ?? value)" }
            .joined(separator: "&")
        request.httpBody = Data(body.utf8)
        return request
    }
}
```

- [ ] **Step 5: Run the test to verify it passes**

Run: `swift test --filter CDYahooOAuthRouterTests`
Expected: PASS

- [ ] **Step 6: Commit**

```bash
git add Source/CDYahooOAuthCredential.swift Source/CDYahooOAuthRouter.swift Tests/CDYahooKitTests/CDYahooOAuthRouterTests.swift
git commit -m "feat(oauth): add CDYahooOAuthCredential and CDYahooOAuthRouter"
```

---

## Task 11: `CDYahooOAuthClient`

**Files:**
- Create: `Source/CDYahooOAuthClient.swift`
- Test: `Tests/CDYahooKitTests/CDYahooOAuthClientTests.swift`

**Interfaces:**
- Consumes: `CDYahooOAuthRouter`, `CDYahooOAuthCredential` (Task 10), `CDYahooKeychain`, `CDYahooDefaults` (Task 5), `CDYahooPKCE` (Task 9), `CDYahooMockURLProtocol` (Task 8).
- Produces: `public final class CDYahooOAuthClient: Sendable { public let clientId, clientSecret, redirectUrl: String; public init(clientId:clientSecret:redirectUrl:urlSession:); public func authorizationURL(codeChallenge: String, state: String) throws -> URL; public func authorize(withCode code: String, codeVerifier: String) async throws; public func isAuthorized() -> Bool; public func validAccessToken() async throws -> String; public func unauthorize() }`.

- [ ] **Step 1: Write the failing test**

```swift
//
//  CDYahooOAuthClientTests.swift
//  CDYahooKitTests
//

import Foundation
import Testing
@testable import CDYahooKit
import CDYahooKitTesting

// .serialized: every test in this suite registers a stub for the same fixed OAuth token
// endpoint URL on CDYahooMockURLProtocol's shared, process-global registry (the token endpoint
// has one real URL — unlike Fantasy API resource endpoints, there's no per-test ID to bake into
// it for the usual "give each registration a unique URL" isolation). Serializing this suite
// stops its own tests from racing each other; it does not protect against interleaving with
// CDYahooFantasyAPIClientTests (Task 13), which is serialized for the same reason but as a
// different suite — an accepted residual risk, not a full fix.
@Suite("CDYahooOAuthClient", .serialized)
struct CDYahooOAuthClientTests {

    private func makeClient() -> CDYahooOAuthClient {
        let configuration = URLSessionConfiguration.ephemeral
        configuration.protocolClasses = [CDYahooMockURLProtocol.self]
        return CDYahooOAuthClient(clientId: "client-id", clientSecret: "client-secret",
                                   redirectUrl: "myapp://callback",
                                   urlSession: URLSession(configuration: configuration))
    }

    @Test("authorizationURL includes PKCE challenge, response_type=code, and state")
    func authorizationURLIncludesRequiredParameters() throws {
        let client = makeClient()
        let url = try client.authorizationURL(codeChallenge: "challenge-value", state: "state-value")
        let query = URLComponents(url: url, resolvingAgainstBaseURL: false)?.queryItems ?? []

        #expect(query.contains { $0.name == "code_challenge" && $0.value == "challenge-value" })
        #expect(query.contains { $0.name == "code_challenge_method" && $0.value == "S256" })
        #expect(query.contains { $0.name == "response_type" && $0.value == "code" })
        #expect(query.contains { $0.name == "state" && $0.value == "state-value" })
        #expect(query.contains { $0.name == "client_id" && $0.value == "client-id" })
    }

    @Test("isAuthorized is false before authorize(withCode:codeVerifier:) succeeds")
    func isAuthorizedFalseBeforeAuthorization() {
        let client = makeClient()
        client.unauthorize()
        #expect(client.isAuthorized() == false)
    }

    @Test("authorize(withCode:codeVerifier:) stores the token and flips isAuthorized to true")
    func authorizeStoresToken() async throws {
        let client = makeClient()
        client.unauthorize()

        CDYahooMockURLProtocol.register(
            stub: .init(statusCode: 200, data: Data("""
            {"access_token":"access-abc","refresh_token":"refresh-abc","expires_in":3600,"token_type":"bearer"}
            """.utf8)),
            for: URL(string: "https://api.login.yahoo.com/oauth2/get_token")!
        )

        try await client.authorize(withCode: "code-abc", codeVerifier: "verifier-abc")
        #expect(client.isAuthorized())
        #expect(try await client.validAccessToken() == "access-abc")
    }

    @Test("validAccessToken throws invalidCredentials when no refresh token is stored")
    func validAccessTokenThrowsWithoutRefreshToken() async {
        let client = makeClient()
        client.unauthorize()

        await #expect(throws: CDYahooKitError.self) {
            _ = try await client.validAccessToken()
        }
    }
}
```

- [ ] **Step 2: Run the test to verify it fails**

Run: `swift test --filter CDYahooOAuthClientTests`
Expected: FAIL — `CDYahooOAuthClient` does not exist

- [ ] **Step 3: Write the implementation**

```swift
//
//  CDYahooOAuthClient.swift
//  CDYahooKit
//

import Foundation

/// Manages the Sign In With Yahoo OAuth 2.0 / PKCE authorization code flow: builds the
/// authorization URL, exchanges a code for a token pair, refreshes silently when the access
/// token has expired, and stores everything in the Keychain via ``CDYahooKeychain``.
public final class CDYahooOAuthClient: Sendable {

    private let session: URLSession
    public let clientId: String
    public let clientSecret: String
    public let redirectUrl: String

    public init(clientId: String, clientSecret: String, redirectUrl: String,
                urlSession: URLSession = URLSession(configuration: .default)) {
        precondition(!clientId.isEmpty && !clientSecret.isEmpty && !redirectUrl.isEmpty,
                     "A clientId, clientSecret, and redirectUrl are required to use Sign In With Yahoo.")
        self.clientId = clientId
        self.clientSecret = clientSecret
        self.redirectUrl = redirectUrl
        self.session = urlSession
    }

    /// The URL to present in an `ASWebAuthenticationSession` to begin the authorization code
    /// flow. `codeChallenge` comes from `CDYahooPKCE.codeChallenge(for:)`; `state` should be a
    /// fresh random value checked against the callback to guard against CSRF.
    public func authorizationURL(codeChallenge: String, state: String) throws -> URL {
        var components = URLComponents(string: CDYahooConstants.oauthAuthorizeURL)
        components?.queryItems = [
            URLQueryItem(name: "client_id", value: clientId),
            URLQueryItem(name: "redirect_uri", value: redirectUrl),
            URLQueryItem(name: "response_type", value: "code"),
            URLQueryItem(name: "code_challenge", value: codeChallenge),
            URLQueryItem(name: "code_challenge_method", value: "S256"),
            URLQueryItem(name: "state", value: state)
        ]
        guard let url = components?.url else {
            throw CDYahooKitError.invalidRequest(underlying: URLError(.badURL))
        }
        return url
    }

    /// Exchanges an authorization `code` (from the callback URL) and the PKCE `codeVerifier`
    /// that produced its challenge for an access/refresh token pair, storing both in the
    /// Keychain.
    public func authorize(withCode code: String, codeVerifier: String) async throws {
        let request = try CDYahooOAuthRouter.authorize(code: code, redirectUrl: redirectUrl, codeVerifier: codeVerifier)
            .asURLRequest(clientId: clientId, clientSecret: clientSecret)
        let credential = try await performTokenRequest(request)
        store(credential)
    }

    public func isAuthorized() -> Bool {
        CDYahooKeychain.string(forKey: CDYahooDefaults.accessToken) != nil
    }

    /// Returns a currently-valid access token, silently refreshing it first if it has expired.
    /// - Throws: ``CDYahooKitError/invalidCredentials(_:)`` if no refresh token is stored — the
    ///   caller must re-run the `ASWebAuthenticationSession` authorization flow.
    public func validAccessToken() async throws -> String {
        if let expiryString = CDYahooKeychain.string(forKey: CDYahooDefaults.tokenExpiry),
           let expiry = Double(expiryString),
           Date().timeIntervalSince1970 < expiry,
           let token = CDYahooKeychain.string(forKey: CDYahooDefaults.accessToken) {
            return token
        }
        guard let refreshToken = CDYahooKeychain.string(forKey: CDYahooDefaults.refreshToken) else {
            throw CDYahooKitError.invalidCredentials("No refresh token stored; re-authorize with Sign In With Yahoo.")
        }
        let request = try CDYahooOAuthRouter.refresh(refreshToken: refreshToken, redirectUrl: redirectUrl)
            .asURLRequest(clientId: clientId, clientSecret: clientSecret)
        let credential = try await performTokenRequest(request)
        store(credential)
        return credential.accessToken
    }

    /// Clears all stored tokens, e.g. on user sign-out.
    public func unauthorize() {
        CDYahooKeychain.delete(forKey: CDYahooDefaults.accessToken)
        CDYahooKeychain.delete(forKey: CDYahooDefaults.refreshToken)
        CDYahooKeychain.delete(forKey: CDYahooDefaults.tokenExpiry)
    }

    private func performTokenRequest(_ request: URLRequest) async throws -> CDYahooOAuthCredential {
        let (data, response) = try await session.data(for: request)
        guard let httpResponse = response as? HTTPURLResponse, (200..<300).contains(httpResponse.statusCode) else {
            throw CDYahooKitError.invalidCredentials("Yahoo's OAuth token endpoint returned a non-2xx response.")
        }
        do {
            return try JSONDecoder().decode(CDYahooOAuthCredential.self, from: data)
        } catch {
            throw CDYahooKitError.responseDecodingFailed(underlying: error)
        }
    }

    private func store(_ credential: CDYahooOAuthCredential) {
        CDYahooKeychain.set(credential.accessToken, forKey: CDYahooDefaults.accessToken)
        if let refreshToken = credential.refreshToken {
            CDYahooKeychain.set(refreshToken, forKey: CDYahooDefaults.refreshToken)
        }
        // Subtract 60s so a token that's about to expire mid-request is refreshed early rather
        // than used and rejected.
        let expiry = Date().timeIntervalSince1970 + Double(credential.expiresIn) - 60
        CDYahooKeychain.set(String(expiry), forKey: CDYahooDefaults.tokenExpiry)
    }
}
```

- [ ] **Step 4: Run the test to verify it passes**

Run: `swift test --filter CDYahooOAuthClientTests`
Expected: PASS

- [ ] **Step 5: Commit**

```bash
git add Source/CDYahooOAuthClient.swift Tests/CDYahooKitTests/CDYahooOAuthClientTests.swift
git commit -m "feat(oauth): add CDYahooOAuthClient with PKCE authorize/refresh"
```

---

## Task 12: `CDYahooAuthSession`

**Files:**
- Create: `Source/CDYahooAuthSession.swift`
- Test: `Tests/CDYahooKitTests/CDYahooAuthSessionTests.swift`

**Interfaces:**
- Consumes: `CDYahooKitError.authorizationCancelled`, `.responseDecodingFailed`, `.invalidCredentials` (Task 1).
- Produces: `public final class CDYahooAuthSession: NSObject { public init(presentationAnchor: @autoclosure @escaping () -> ASPresentationAnchor); public func authorize(authorizationURL: URL, callbackScheme: String) async throws -> URL; static func mapCallback(url: URL?, error: (any Error)?) throws -> URL; static func extractCode(from callbackURL: URL, expectedState: String) throws -> String }`.

- [ ] **Step 1: Write the failing test**

Only the pure static functions are unit-testable — presenting the real browser sheet isn't (same limitation CDOAuth1Kit's `CDOAuth1AuthSessionTests` accepts for `CDOAuth1AuthSession`).

```swift
//
//  CDYahooAuthSessionTests.swift
//  CDYahooKitTests
//

import AuthenticationServices
import Foundation
import Testing
@testable import CDYahooKit

@Suite("CDYahooAuthSession")
struct CDYahooAuthSessionTests {

    @Test("mapCallback returns the callback URL when there's no error")
    func mapCallbackReturnsURL() throws {
        let url = URL(string: "myapp://callback?code=abc&state=xyz")!
        #expect(try CDYahooAuthSession.mapCallback(url: url, error: nil) == url)
    }

    @Test("mapCallback throws authorizationCancelled for a cancelled login")
    func mapCallbackThrowsOnCancellation() throws {
        let error = ASWebAuthenticationSessionError(.canceledLogin)
        let thrown = try #require(throws: CDYahooKitError.self) {
            _ = try CDYahooAuthSession.mapCallback(url: nil, error: error)
        }
        guard case .authorizationCancelled = thrown else {
            Issue.record("Expected .authorizationCancelled, got \(thrown)")
            return
        }
    }

    @Test("mapCallback throws responseDecodingFailed when both url and error are nil")
    func mapCallbackThrowsWhenBothNil() {
        #expect(throws: CDYahooKitError.self) {
            _ = try CDYahooAuthSession.mapCallback(url: nil, error: nil)
        }
    }

    @Test("extractCode returns the code when state matches")
    func extractCodeReturnsCodeOnMatchingState() throws {
        let url = URL(string: "myapp://callback?code=abc123&state=xyz")!
        #expect(try CDYahooAuthSession.extractCode(from: url, expectedState: "xyz") == "abc123")
    }

    @Test("extractCode throws invalidCredentials when state doesn't match")
    func extractCodeThrowsOnStateMismatch() {
        let url = URL(string: "myapp://callback?code=abc123&state=wrong")!
        #expect(throws: CDYahooKitError.self) {
            _ = try CDYahooAuthSession.extractCode(from: url, expectedState: "xyz")
        }
    }

    @Test("extractCode throws invalidCredentials when the code is missing")
    func extractCodeThrowsWhenCodeMissing() {
        let url = URL(string: "myapp://callback?state=xyz")!
        #expect(throws: CDYahooKitError.self) {
            _ = try CDYahooAuthSession.extractCode(from: url, expectedState: "xyz")
        }
    }
}
```

- [ ] **Step 2: Run the test to verify it fails**

Run: `swift test --filter CDYahooAuthSessionTests`
Expected: FAIL — `CDYahooAuthSession` does not exist

- [ ] **Step 3: Write the implementation**

```swift
//
//  CDYahooAuthSession.swift
//  CDYahooKit
//

import AuthenticationServices
import Foundation

/// An `async`/`await` wrapper around `ASWebAuthenticationSession` for the browser-redirect step
/// of Sign In With Yahoo's OAuth 2.0 authorization code flow — modeled directly on CDOAuth1Kit's
/// `CDOAuth1AuthSession`. The only functional difference is what comes back in the callback URL:
/// an OAuth 1.0a `oauth_verifier` there, versus an OAuth 2.0 `code` (+ `state`) here.
///
/// ```swift
/// let verifier = CDYahooPKCE.makeCodeVerifier()
/// let challenge = CDYahooPKCE.codeChallenge(for: verifier)
/// let state = UUID().uuidString
/// let authURL = try oAuthClient.authorizationURL(codeChallenge: challenge, state: state)
/// let callback = try await CDYahooAuthSession(presentationAnchor: view.window!)
///     .authorize(authorizationURL: authURL, callbackScheme: "myapp")
/// let code = try CDYahooAuthSession.extractCode(from: callback, expectedState: state)
/// try await oAuthClient.authorize(withCode: code, codeVerifier: verifier)
/// ```
@available(iOS 12.0, macOS 10.15, visionOS 1.0, *)
public final class CDYahooAuthSession: NSObject {

    private let presentationAnchorProvider: () -> ASPresentationAnchor

    /// Retains the in-flight `ASWebAuthenticationSession` — see `CDOAuth1AuthSession`'s
    /// identical property for why this is required rather than incidental.
    private var activeSession: ASWebAuthenticationSession?

    public init(presentationAnchor: @autoclosure @escaping () -> ASPresentationAnchor) {
        self.presentationAnchorProvider = presentationAnchor
        super.init()
    }

    public func authorize(authorizationURL: URL, callbackScheme: String) async throws -> URL {
        try await withCheckedThrowingContinuation { continuation in
            let session = ASWebAuthenticationSession(
                url: authorizationURL,
                callbackURLScheme: callbackScheme
            ) { [weak self] callbackURL, error in
                self?.activeSession = nil
                do {
                    try continuation.resume(returning: Self.mapCallback(url: callbackURL, error: error))
                } catch {
                    continuation.resume(throwing: error)
                }
            }
            session.presentationContextProvider = self
            activeSession = session
            session.start()
        }
    }

    static func mapCallback(url callbackURL: URL?, error: (any Error)?) throws -> URL {
        if let error = error as? ASWebAuthenticationSessionError, error.code == .canceledLogin {
            throw CDYahooKitError.authorizationCancelled
        }
        if let error {
            throw error
        }
        guard let callbackURL else {
            throw CDYahooKitError.responseDecodingFailed(underlying: URLError(.badServerResponse))
        }
        return callbackURL
    }

    /// Extracts the OAuth 2.0 authorization `code` from a callback URL, verifying its `state`
    /// query item matches `expectedState` first, as a CSRF guard.
    public static func extractCode(from callbackURL: URL, expectedState: String) throws -> String {
        let items = URLComponents(url: callbackURL, resolvingAgainstBaseURL: false)?.queryItems ?? []
        guard let state = items.first(where: { $0.name == "state" })?.value, state == expectedState else {
            throw CDYahooKitError.invalidCredentials("OAuth state mismatch; possible CSRF, discard this callback.")
        }
        guard let code = items.first(where: { $0.name == "code" })?.value else {
            throw CDYahooKitError.invalidCredentials("Authorization callback did not include a code.")
        }
        return code
    }
}

@available(iOS 12.0, macOS 10.15, visionOS 1.0, *)
extension CDYahooAuthSession: ASWebAuthenticationPresentationContextProviding {
    public func presentationAnchor(for session: ASWebAuthenticationSession) -> ASPresentationAnchor {
        presentationAnchorProvider()
    }
}
```

- [ ] **Step 4: Run the test to verify it passes**

Run: `swift test --filter CDYahooAuthSessionTests`
Expected: PASS

- [ ] **Step 5: Commit**

```bash
git add Source/CDYahooAuthSession.swift Tests/CDYahooKitTests/CDYahooAuthSessionTests.swift
git commit -m "feat(oauth): add CDYahooAuthSession ASWebAuthenticationSession wrapper"
```

---

## Task 13: `CDYahooRouter` + `CDYahooFantasyAPIClient` scaffold + `fetchUserGames`

**Files:**
- Create: `Source/CDYahooRouter.swift`
- Create: `Source/CDYahooFantasyAPIClient.swift`
- Create: `Source/CDYahooGame.swift`
- Create: `Source/CDYahooUserGamesResponse.swift`
- Create: `Tests/CDYahooKitTests/Fixtures/UserGames.xml`
- Modify: `Package.swift` — add `resources: [.process("Fixtures")]` to the test target
- Test: `Tests/CDYahooKitTests/CDYahooFantasyAPIClientTests.swift`

**Interfaces:**
- Consumes: `CDYahooURLSession` (Task 7), `CDYahooOAuthClient` (Task 11), `CDYahooXMLDecodable`, `CDYahooXMLNode`, `CDYahooXMLDecodingError` (Tasks 3-4), `CDYahooMockURLProtocol` (Task 8).
- Produces: `enum CDYahooRouter { case userGames(gameCode: String); ...; func asURLRequest(accessToken: String) throws -> URLRequest }`, `@MainActor public final class CDYahooFantasyAPIClient { public let oAuthClient: CDYahooOAuthClient; public init(clientId:clientSecret:redirectUrl:urlSession:retryConfiguration:eventMonitors:requestAdapters:cacheConfiguration:); public func fetchUserGames(gameCode: String = "nfl") async throws -> CDYahooUserGamesResponse }`, `public struct CDYahooLeagueSummary: CDYahooXMLDecodable, Sendable, Equatable`, `public struct CDYahooGame: CDYahooXMLDecodable, Sendable, Equatable`, `public struct CDYahooUserGamesResponse: CDYahooXMLDecodable, Sendable`.

- [ ] **Step 1: Modify `Package.swift`**

Add the `Fixtures` resource to the test target:

```swift
        .testTarget(name: "CDYahooKitTests",
                    dependencies: ["CDYahooKit", "CDYahooKitTesting"],
                    path: "Tests/CDYahooKitTests",
                    resources: [.process("Fixtures")])
```

- [ ] **Step 2: Create `Tests/CDYahooKitTests/Fixtures/UserGames.xml`**

```xml
<?xml version="1.0" encoding="UTF-8"?>
<fantasy_content xml:lang="en-US" time="1.23">
    <users count="1">
        <user>
            <guid>ABCDEF123456</guid>
            <games count="1">
                <game>
                    <game_key>449</game_key>
                    <game_id>449</game_id>
                    <name>Football</name>
                    <code>nfl</code>
                    <season>2025</season>
                    <leagues count="1">
                        <league>
                            <league_key>449.l.12345</league_key>
                            <league_id>12345</league_id>
                            <name>My Fantasy League</name>
                            <num_teams>10</num_teams>
                        </league>
                    </leagues>
                </game>
            </games>
        </user>
    </users>
</fantasy_content>
```

- [ ] **Step 3: Write the failing test**

```swift
//
//  CDYahooFantasyAPIClientTests.swift
//  CDYahooKitTests
//

import Foundation
import Testing
@testable import CDYahooKit
import CDYahooKitTesting

// .serialized for the same reason as CDYahooOAuthClientTests (Task 11): every test here also
// stubs the fixed OAuth token endpoint URL via stubTokenEndpoint() before exercising a Fantasy
// API call.
@MainActor
@Suite("CDYahooFantasyAPIClient", .serialized)
struct CDYahooFantasyAPIClientTests {

    private func makeClient() -> CDYahooFantasyAPIClient {
        let configuration = URLSessionConfiguration.ephemeral
        configuration.protocolClasses = [CDYahooMockURLProtocol.self]
        let client = CDYahooFantasyAPIClient(clientId: "client-id", clientSecret: "client-secret",
                                              redirectUrl: "myapp://callback",
                                              urlSession: URLSession(configuration: configuration))
        client.oAuthClient.unauthorize()
        return client
    }

    private func fixtureData(_ name: String) throws -> Data {
        let url = try #require(Bundle.module.url(forResource: name, withExtension: "xml"))
        return try Data(contentsOf: url)
    }

    private func stubTokenEndpoint() {
        CDYahooMockURLProtocol.register(
            stub: .init(statusCode: 200, data: Data("""
            {"access_token":"access-abc","refresh_token":"refresh-abc","expires_in":3600,"token_type":"bearer"}
            """.utf8)),
            for: URL(string: "https://api.login.yahoo.com/oauth2/get_token")!
        )
    }

    @Test("fetchUserGames decodes the authenticated user's games and leagues")
    func fetchUserGamesDecodesFixture() async throws {
        let client = makeClient()
        stubTokenEndpoint()
        try await client.oAuthClient.authorize(withCode: "code", codeVerifier: "verifier")

        CDYahooMockURLProtocol.register(
            stub: .init(statusCode: 200, data: try fixtureData("UserGames")),
            for: URL(string: "https://fantasysports.yahooapis.com/fantasy/v2/users;use_login=1/games;game_codes=nfl/leagues")!
        )

        let response = try await client.fetchUserGames()
        #expect(response.games.count == 1)

        let game = try #require(response.games.first)
        #expect(game.gameKey == "449")
        #expect(game.code == "nfl")
        #expect(game.season == "2025")

        let league = try #require(game.leagues.first)
        #expect(league.leagueKey == "449.l.12345")
        #expect(league.name == "My Fantasy League")
        #expect(league.numTeams == 10)
    }
}
```

- [ ] **Step 4: Run the test to verify it fails**

Run: `swift test --filter CDYahooFantasyAPIClientTests`
Expected: FAIL — `CDYahooFantasyAPIClient` does not exist

- [ ] **Step 5: Write `Source/CDYahooRouter.swift`**

```swift
//
//  CDYahooRouter.swift
//  CDYahooKit
//

import Foundation

/// Builds requests against the Yahoo Fantasy Sports API (`fantasysports.yahooapis.com/fantasy/v2/`).
/// Every case is a read-only `GET` for v1.
enum CDYahooRouter {
    case userGames(gameCode: String)

    var path: String {
        switch self {
        case let .userGames(gameCode):
            "users;use_login=1/games;game_codes=\(gameCode)/leagues"
        }
    }

    func asURLRequest(accessToken: String) throws -> URLRequest {
        guard let url = URL(string: CDYahooConstants.fantasyBaseURL + path) else {
            throw CDYahooKitError.invalidRequest(underlying: URLError(.badURL))
        }
        var request = URLRequest(url: url)
        request.httpMethod = "GET"
        request.setValue("Bearer \(accessToken)", forHTTPHeaderField: "Authorization")
        request.setValue("application/xml", forHTTPHeaderField: "Accept")
        return request
    }
}
```

- [ ] **Step 6: Write `Source/CDYahooGame.swift`**

```swift
//
//  CDYahooGame.swift
//  CDYahooKit
//

/// A team's league within one fantasy game/season, as summarized inside `CDYahooGame`.
public struct CDYahooLeagueSummary: CDYahooXMLDecodable, Sendable, Equatable {
    public let leagueKey: String
    public let leagueId: String
    public let name: String
    public let numTeams: Int?

    init(node: CDYahooXMLNode) throws {
        guard let leagueKey = node.text("league_key"), let leagueId = node.text("league_id"), let name = node.text("name") else {
            throw CDYahooXMLDecodingError.missingField("league")
        }
        self.leagueKey = leagueKey
        self.leagueId = leagueId
        self.name = name
        self.numTeams = node.int("num_teams")
    }
}

/// A fantasy game (a sport + season, e.g. "Football" / "nfl" / 2025) the authenticated user has
/// one or more leagues in.
public struct CDYahooGame: CDYahooXMLDecodable, Sendable, Equatable {
    public let gameKey: String
    public let gameId: String
    public let name: String
    public let code: String
    public let season: String
    public let leagues: [CDYahooLeagueSummary]

    init(node: CDYahooXMLNode) throws {
        guard let gameKey = node.text("game_key"), let gameId = node.text("game_id"), let name = node.text("name"),
              let code = node.text("code"), let season = node.text("season") else {
            throw CDYahooXMLDecodingError.missingField("game")
        }
        self.gameKey = gameKey
        self.gameId = gameId
        self.name = name
        self.code = code
        self.season = season
        self.leagues = try node.child("leagues")?.children("league").map(CDYahooLeagueSummary.init(node:)) ?? []
    }
}
```

- [ ] **Step 7: Write `Source/CDYahooUserGamesResponse.swift`**

```swift
//
//  CDYahooUserGamesResponse.swift
//  CDYahooKit
//

/// The response from `users;use_login=1/games;game_codes={code}/leagues` — every fantasy game
/// and league the authenticated user has a team in for the requested game code.
public struct CDYahooUserGamesResponse: CDYahooXMLDecodable, Sendable {
    public let games: [CDYahooGame]

    init(node: CDYahooXMLNode) throws {
        guard let user = node.child("users")?.child("user") else {
            throw CDYahooXMLDecodingError.missingField("users/user")
        }
        self.games = try user.child("games")?.children("game").map(CDYahooGame.init(node:)) ?? []
    }
}
```

- [ ] **Step 8: Write `Source/CDYahooFantasyAPIClient.swift`**

```swift
//
//  CDYahooFantasyAPIClient.swift
//  CDYahooKit
//

import Foundation

/// The primary client for the Yahoo Fantasy Sports API. Create one instance per application and
/// hold a strong reference to it. All methods are `@MainActor`.
@MainActor
public final class CDYahooFantasyAPIClient {

    private let session: CDYahooURLSession
    public let oAuthClient: CDYahooOAuthClient

    public init(clientId: String, clientSecret: String, redirectUrl: String,
                urlSession: URLSession = URLSession(configuration: .default),
                retryConfiguration: CDYahooRetryConfiguration = .disabled,
                eventMonitors: [any CDYahooEventMonitor] = [],
                requestAdapters: [any CDYahooRequestAdapter] = [],
                cacheConfiguration: CDYahooCacheConfiguration = .disabled) {
        self.oAuthClient = CDYahooOAuthClient(clientId: clientId, clientSecret: clientSecret, redirectUrl: redirectUrl,
                                               urlSession: urlSession)
        self.session = CDYahooURLSession(session: urlSession, retryConfiguration: retryConfiguration,
                                          eventMonitors: eventMonitors, requestAdapters: requestAdapters,
                                          cacheConfiguration: cacheConfiguration)
    }

    private func authorizedRequest(_ route: CDYahooRouter) async throws -> URLRequest {
        let token = try await oAuthClient.validAccessToken()
        return try route.asURLRequest(accessToken: token)
    }

    /// Fetches every fantasy game/season and league the authenticated user has a team in.
    /// - Parameter gameCode: The Yahoo game code, e.g. `"nfl"`, `"mlb"`, `"nba"`, `"nhl"`.
    public func fetchUserGames(gameCode: String = "nfl") async throws -> CDYahooUserGamesResponse {
        let request = try await authorizedRequest(.userGames(gameCode: gameCode))
        return try await session.perform(request)
    }
}
```

- [ ] **Step 9: Run the test to verify it passes**

Run: `swift test --filter CDYahooFantasyAPIClientTests`
Expected: PASS

- [ ] **Step 10: Commit**

```bash
git add Package.swift Source/CDYahooRouter.swift Source/CDYahooFantasyAPIClient.swift Source/CDYahooGame.swift Source/CDYahooUserGamesResponse.swift Tests/CDYahooKitTests/Fixtures/UserGames.xml Tests/CDYahooKitTests/CDYahooFantasyAPIClientTests.swift
git commit -m "feat(fantasy): add CDYahooFantasyAPIClient with fetchUserGames"
```

---

## Task 14: `fetchLeague`

**Files:**
- Create: `Source/CDYahooLeague.swift`
- Create: `Source/CDYahooLeagueResponse.swift`
- Create: `Tests/CDYahooKitTests/Fixtures/League.xml`
- Modify: `Source/CDYahooRouter.swift` — add `.league(leagueKey:)` case
- Modify: `Source/CDYahooFantasyAPIClient.swift` — add `fetchLeague(leagueKey:)`
- Modify: `Tests/CDYahooKitTests/CDYahooFantasyAPIClientTests.swift` — add the test

**Interfaces:**
- Consumes: everything from Task 13.
- Produces: `public struct CDYahooLeague: CDYahooXMLDecodable, Sendable, Equatable`, `public struct CDYahooLeagueResponse: CDYahooXMLDecodable, Sendable`, `CDYahooFantasyAPIClient.fetchLeague(leagueKey: String) async throws -> CDYahooLeagueResponse`.

- [ ] **Step 1: Create `Tests/CDYahooKitTests/Fixtures/League.xml`**

```xml
<?xml version="1.0" encoding="UTF-8"?>
<fantasy_content xml:lang="en-US" time="1.23">
    <league>
        <league_key>449.l.12345</league_key>
        <league_id>12345</league_id>
        <name>My Fantasy League</name>
        <url>https://football.fantasysports.yahoo.com/f1/12345</url>
        <num_teams>10</num_teams>
        <scoring_type>head</scoring_type>
        <current_week>8</current_week>
        <season>2025</season>
    </league>
</fantasy_content>
```

- [ ] **Step 2: Add the failing test to `CDYahooFantasyAPIClientTests.swift`**

```swift
    @Test("fetchLeague decodes league metadata")
    func fetchLeagueDecodesFixture() async throws {
        let client = makeClient()
        stubTokenEndpoint()
        try await client.oAuthClient.authorize(withCode: "code", codeVerifier: "verifier")

        CDYahooMockURLProtocol.register(
            stub: .init(statusCode: 200, data: try fixtureData("League")),
            for: URL(string: "https://fantasysports.yahooapis.com/fantasy/v2/league/449.l.12345")!
        )

        let response = try await client.fetchLeague(leagueKey: "449.l.12345")
        #expect(response.league.name == "My Fantasy League")
        #expect(response.league.numTeams == 10)
        #expect(response.league.scoringType == "head")
        #expect(response.league.currentWeek == 8)
    }
```

- [ ] **Step 3: Run the test to verify it fails**

Run: `swift test --filter fetchLeagueDecodesFixture`
Expected: FAIL — `.league` router case / `fetchLeague` do not exist

- [ ] **Step 4: Add the `.league` case to `Source/CDYahooRouter.swift`**

```swift
enum CDYahooRouter {
    case userGames(gameCode: String)
    case league(leagueKey: String)

    var path: String {
        switch self {
        case let .userGames(gameCode):
            "users;use_login=1/games;game_codes=\(gameCode)/leagues"
        case let .league(leagueKey):
            "league/\(leagueKey)"
        }
    }
```

- [ ] **Step 5: Write `Source/CDYahooLeague.swift`**

```swift
//
//  CDYahooLeague.swift
//  CDYahooKit
//

/// A fantasy league's metadata and settings.
public struct CDYahooLeague: CDYahooXMLDecodable, Sendable, Equatable {
    public let leagueKey: String
    public let leagueId: String
    public let name: String
    public let url: String?
    public let numTeams: Int?
    public let scoringType: String?
    public let currentWeek: Int?
    public let season: String?

    init(node: CDYahooXMLNode) throws {
        guard let leagueKey = node.text("league_key"), let leagueId = node.text("league_id"), let name = node.text("name") else {
            throw CDYahooXMLDecodingError.missingField("league")
        }
        self.leagueKey = leagueKey
        self.leagueId = leagueId
        self.name = name
        self.url = node.text("url")
        self.numTeams = node.int("num_teams")
        self.scoringType = node.text("scoring_type")
        self.currentWeek = node.int("current_week")
        self.season = node.text("season")
    }
}
```

- [ ] **Step 6: Write `Source/CDYahooLeagueResponse.swift`**

```swift
//
//  CDYahooLeagueResponse.swift
//  CDYahooKit
//

/// The response from `league/{league_key}`.
public struct CDYahooLeagueResponse: CDYahooXMLDecodable, Sendable {
    public let league: CDYahooLeague

    init(node: CDYahooXMLNode) throws {
        guard let leagueNode = node.child("league") else {
            throw CDYahooXMLDecodingError.missingField("league")
        }
        self.league = try CDYahooLeague(node: leagueNode)
    }
}
```

- [ ] **Step 7: Add `fetchLeague` to `Source/CDYahooFantasyAPIClient.swift`**

```swift
    /// Fetches a league's metadata and settings.
    public func fetchLeague(leagueKey: String) async throws -> CDYahooLeagueResponse {
        let request = try await authorizedRequest(.league(leagueKey: leagueKey))
        return try await session.perform(request)
    }
```

- [ ] **Step 8: Run the test to verify it passes**

Run: `swift test --filter CDYahooFantasyAPIClientTests`
Expected: PASS (all tests in the suite, including Task 13's)

- [ ] **Step 9: Commit**

```bash
git add Source/CDYahooRouter.swift Source/CDYahooFantasyAPIClient.swift Source/CDYahooLeague.swift Source/CDYahooLeagueResponse.swift Tests/CDYahooKitTests/Fixtures/League.xml Tests/CDYahooKitTests/CDYahooFantasyAPIClientTests.swift
git commit -m "feat(fantasy): add fetchLeague"
```

---

## Task 15: `fetchLeagueStandings`

**Files:**
- Create: `Source/CDYahooLeagueStandingsResponse.swift`
- Create: `Tests/CDYahooKitTests/Fixtures/LeagueStandings.xml`
- Modify: `Source/CDYahooRouter.swift` — add `.standings(leagueKey:)` case
- Modify: `Source/CDYahooFantasyAPIClient.swift` — add `fetchLeagueStandings(leagueKey:)`
- Modify: `Tests/CDYahooKitTests/CDYahooFantasyAPIClientTests.swift` — add the test

**Interfaces:**
- Produces: `public struct CDYahooTeamOutcomeTotals: CDYahooXMLDecodable, Sendable, Equatable`, `public struct CDYahooTeamStanding: CDYahooXMLDecodable, Sendable, Equatable`, `public struct CDYahooLeagueStandingsResponse: CDYahooXMLDecodable, Sendable`, `CDYahooFantasyAPIClient.fetchLeagueStandings(leagueKey: String) async throws -> CDYahooLeagueStandingsResponse`.

- [ ] **Step 1: Create `Tests/CDYahooKitTests/Fixtures/LeagueStandings.xml`**

```xml
<?xml version="1.0" encoding="UTF-8"?>
<fantasy_content xml:lang="en-US" time="1.23">
    <league>
        <league_key>449.l.12345</league_key>
        <name>My Fantasy League</name>
        <standings>
            <teams count="2">
                <team>
                    <team_key>449.l.12345.t.1</team_key>
                    <team_id>1</team_id>
                    <name>Team Alpha</name>
                    <team_standings>
                        <rank>1</rank>
                        <outcome_totals>
                            <wins>8</wins>
                            <losses>3</losses>
                            <ties>0</ties>
                            <percentage>.727</percentage>
                        </outcome_totals>
                        <points_for>1234.5</points_for>
                        <points_against>1100.2</points_against>
                    </team_standings>
                </team>
                <team>
                    <team_key>449.l.12345.t.2</team_key>
                    <team_id>2</team_id>
                    <name>Team Beta</name>
                    <team_standings>
                        <rank>2</rank>
                        <outcome_totals>
                            <wins>6</wins>
                            <losses>5</losses>
                            <ties>0</ties>
                            <percentage>.545</percentage>
                        </outcome_totals>
                        <points_for>1150.0</points_for>
                        <points_against>1120.8</points_against>
                    </team_standings>
                </team>
            </teams>
        </standings>
    </league>
</fantasy_content>
```

- [ ] **Step 2: Add the failing test**

```swift
    @Test("fetchLeagueStandings decodes ranked teams with outcome totals")
    func fetchLeagueStandingsDecodesFixture() async throws {
        let client = makeClient()
        stubTokenEndpoint()
        try await client.oAuthClient.authorize(withCode: "code", codeVerifier: "verifier")

        CDYahooMockURLProtocol.register(
            stub: .init(statusCode: 200, data: try fixtureData("LeagueStandings")),
            for: URL(string: "https://fantasysports.yahooapis.com/fantasy/v2/league/449.l.12345/standings")!
        )

        let response = try await client.fetchLeagueStandings(leagueKey: "449.l.12345")
        #expect(response.teams.count == 2)

        let first = try #require(response.teams.first)
        #expect(first.name == "Team Alpha")
        #expect(first.rank == 1)
        #expect(first.outcomeTotals?.wins == 8)
        #expect(first.pointsFor == 1234.5)
    }
```

- [ ] **Step 3: Run the test to verify it fails**

Run: `swift test --filter fetchLeagueStandingsDecodesFixture`
Expected: FAIL

- [ ] **Step 4: Add the `.standings` case to `Source/CDYahooRouter.swift`**

```swift
        case standings(leagueKey: String)
```

and in `path`:

```swift
        case let .standings(leagueKey):
            "league/\(leagueKey)/standings"
```

- [ ] **Step 5: Write `Source/CDYahooLeagueStandingsResponse.swift`**

```swift
//
//  CDYahooLeagueStandingsResponse.swift
//  CDYahooKit
//

/// A team's regular-season win/loss/tie record and points.
public struct CDYahooTeamOutcomeTotals: CDYahooXMLDecodable, Sendable, Equatable {
    public let wins: Int
    public let losses: Int
    public let ties: Int
    public let percentage: String

    init(node: CDYahooXMLNode) throws {
        self.wins = node.int("wins") ?? 0
        self.losses = node.int("losses") ?? 0
        self.ties = node.int("ties") ?? 0
        self.percentage = node.text("percentage") ?? "0.000"
    }
}

/// One team's row in a league's standings.
public struct CDYahooTeamStanding: CDYahooXMLDecodable, Sendable, Equatable {
    public let teamKey: String
    public let teamId: String
    public let name: String
    public let rank: Int?
    public let outcomeTotals: CDYahooTeamOutcomeTotals?
    public let pointsFor: Double?
    public let pointsAgainst: Double?

    init(node: CDYahooXMLNode) throws {
        guard let teamKey = node.text("team_key"), let teamId = node.text("team_id"), let name = node.text("name") else {
            throw CDYahooXMLDecodingError.missingField("team")
        }
        self.teamKey = teamKey
        self.teamId = teamId
        self.name = name
        let standingsNode = node.child("team_standings")
        self.rank = standingsNode?.int("rank")
        self.outcomeTotals = try standingsNode?.child("outcome_totals").map(CDYahooTeamOutcomeTotals.init(node:))
        self.pointsFor = standingsNode?.text("points_for").flatMap(Double.init)
        self.pointsAgainst = standingsNode?.text("points_against").flatMap(Double.init)
    }
}

/// The response from `league/{league_key}/standings`.
public struct CDYahooLeagueStandingsResponse: CDYahooXMLDecodable, Sendable {
    public let leagueKey: String
    public let teams: [CDYahooTeamStanding]

    init(node: CDYahooXMLNode) throws {
        guard let leagueNode = node.child("league"), let leagueKey = leagueNode.text("league_key") else {
            throw CDYahooXMLDecodingError.missingField("league")
        }
        self.leagueKey = leagueKey
        let teamNodes = leagueNode.child("standings")?.child("teams")?.children("team") ?? []
        self.teams = try teamNodes.map(CDYahooTeamStanding.init(node:))
    }
}
```

- [ ] **Step 6: Add `fetchLeagueStandings` to `Source/CDYahooFantasyAPIClient.swift`**

```swift
    /// Fetches a league's current standings, ranked by team.
    public func fetchLeagueStandings(leagueKey: String) async throws -> CDYahooLeagueStandingsResponse {
        let request = try await authorizedRequest(.standings(leagueKey: leagueKey))
        return try await session.perform(request)
    }
```

- [ ] **Step 7: Run the test to verify it passes**

Run: `swift test --filter CDYahooFantasyAPIClientTests`
Expected: PASS

- [ ] **Step 8: Commit**

```bash
git add Source/CDYahooRouter.swift Source/CDYahooFantasyAPIClient.swift Source/CDYahooLeagueStandingsResponse.swift Tests/CDYahooKitTests/Fixtures/LeagueStandings.xml Tests/CDYahooKitTests/CDYahooFantasyAPIClientTests.swift
git commit -m "feat(fantasy): add fetchLeagueStandings"
```

---

## Task 16: `fetchTeamRoster`

**Files:**
- Create: `Source/CDYahooPlayer.swift`
- Create: `Source/CDYahooTeamRosterResponse.swift`
- Create: `Tests/CDYahooKitTests/Fixtures/TeamRoster.xml`
- Modify: `Source/CDYahooRouter.swift` — add `.roster(teamKey:week:)` case
- Modify: `Source/CDYahooFantasyAPIClient.swift` — add `fetchTeamRoster(teamKey:week:)`
- Modify: `Tests/CDYahooKitTests/CDYahooFantasyAPIClientTests.swift` — add the test

**Interfaces:**
- Produces: `public struct CDYahooPlayer: CDYahooXMLDecodable, Sendable, Equatable`, `public struct CDYahooTeamRosterResponse: CDYahooXMLDecodable, Sendable`, `CDYahooFantasyAPIClient.fetchTeamRoster(teamKey: String, week: Int?) async throws -> CDYahooTeamRosterResponse`.

- [ ] **Step 1: Create `Tests/CDYahooKitTests/Fixtures/TeamRoster.xml`**

```xml
<?xml version="1.0" encoding="UTF-8"?>
<fantasy_content xml:lang="en-US" time="1.23">
    <team>
        <team_key>449.l.12345.t.1</team_key>
        <name>Team Alpha</name>
        <roster>
            <players count="2">
                <player>
                    <player_key>449.p.30123</player_key>
                    <player_id>30123</player_id>
                    <name>
                        <full>Jane Doe</full>
                    </name>
                    <editorial_team_abbr>SF</editorial_team_abbr>
                    <display_position>QB</display_position>
                    <selected_position>
                        <position>QB</position>
                    </selected_position>
                </player>
                <player>
                    <player_key>449.p.30456</player_key>
                    <player_id>30456</player_id>
                    <name>
                        <full>John Roe</full>
                    </name>
                    <editorial_team_abbr>DAL</editorial_team_abbr>
                    <display_position>RB</display_position>
                    <selected_position>
                        <position>BN</position>
                    </selected_position>
                </player>
            </players>
        </roster>
    </team>
</fantasy_content>
```

- [ ] **Step 2: Add the failing test**

```swift
    @Test("fetchTeamRoster decodes players with their selected position")
    func fetchTeamRosterDecodesFixture() async throws {
        let client = makeClient()
        stubTokenEndpoint()
        try await client.oAuthClient.authorize(withCode: "code", codeVerifier: "verifier")

        CDYahooMockURLProtocol.register(
            stub: .init(statusCode: 200, data: try fixtureData("TeamRoster")),
            for: URL(string: "https://fantasysports.yahooapis.com/fantasy/v2/team/449.l.12345.t.1/roster;week=8")!
        )

        let response = try await client.fetchTeamRoster(teamKey: "449.l.12345.t.1", week: 8)
        #expect(response.players.count == 2)

        let quarterback = try #require(response.players.first)
        #expect(quarterback.fullName == "Jane Doe")
        #expect(quarterback.selectedPosition == "QB")

        let benched = response.players[1]
        #expect(benched.selectedPosition == "BN")
    }
```

- [ ] **Step 3: Run the test to verify it fails**

Run: `swift test --filter fetchTeamRosterDecodesFixture`
Expected: FAIL

- [ ] **Step 4: Add the `.roster` case to `Source/CDYahooRouter.swift`**

```swift
        case roster(teamKey: String, week: Int?)
```

and in `path`:

```swift
        case let .roster(teamKey, week):
            if let week {
                "team/\(teamKey)/roster;week=\(week)"
            } else {
                "team/\(teamKey)/roster"
            }
```

- [ ] **Step 5: Write `Source/CDYahooPlayer.swift`**

```swift
//
//  CDYahooPlayer.swift
//  CDYahooKit
//

/// A player, as they appear on a team roster or in a league's player pool.
public struct CDYahooPlayer: CDYahooXMLDecodable, Sendable, Equatable {
    public let playerKey: String
    public let playerId: String
    public let fullName: String
    public let editorialTeamAbbr: String?
    public let displayPosition: String?
    public let selectedPosition: String?
    public let status: String?

    init(node: CDYahooXMLNode) throws {
        guard let playerKey = node.text("player_key"), let playerId = node.text("player_id"),
              let fullName = node.child("name")?.text("full") else {
            throw CDYahooXMLDecodingError.missingField("player")
        }
        self.playerKey = playerKey
        self.playerId = playerId
        self.fullName = fullName
        self.editorialTeamAbbr = node.text("editorial_team_abbr")
        self.displayPosition = node.text("display_position")
        self.selectedPosition = node.child("selected_position")?.text("position")
        self.status = node.text("status")
    }
}
```

- [ ] **Step 6: Write `Source/CDYahooTeamRosterResponse.swift`**

```swift
//
//  CDYahooTeamRosterResponse.swift
//  CDYahooKit
//

/// The response from `team/{team_key}/roster` (optionally `;week={week}`).
public struct CDYahooTeamRosterResponse: CDYahooXMLDecodable, Sendable {
    public let teamKey: String
    public let name: String
    public let players: [CDYahooPlayer]

    init(node: CDYahooXMLNode) throws {
        guard let teamNode = node.child("team"), let teamKey = teamNode.text("team_key"), let name = teamNode.text("name") else {
            throw CDYahooXMLDecodingError.missingField("team")
        }
        self.teamKey = teamKey
        self.name = name
        let playerNodes = teamNode.child("roster")?.child("players")?.children("player") ?? []
        self.players = try playerNodes.map(CDYahooPlayer.init(node:))
    }
}
```

- [ ] **Step 7: Add `fetchTeamRoster` to `Source/CDYahooFantasyAPIClient.swift`**

```swift
    /// Fetches a team's roster. Pass `week` to see the roster as it was set for a specific week;
    /// pass `nil` for the current roster.
    public func fetchTeamRoster(teamKey: String, week: Int?) async throws -> CDYahooTeamRosterResponse {
        let request = try await authorizedRequest(.roster(teamKey: teamKey, week: week))
        return try await session.perform(request)
    }
```

- [ ] **Step 8: Run the test to verify it passes**

Run: `swift test --filter CDYahooFantasyAPIClientTests`
Expected: PASS

- [ ] **Step 9: Commit**

```bash
git add Source/CDYahooRouter.swift Source/CDYahooFantasyAPIClient.swift Source/CDYahooPlayer.swift Source/CDYahooTeamRosterResponse.swift Tests/CDYahooKitTests/Fixtures/TeamRoster.xml Tests/CDYahooKitTests/CDYahooFantasyAPIClientTests.swift
git commit -m "feat(fantasy): add fetchTeamRoster"
```

---

## Task 17: `fetchLeaguePlayers`

**Files:**
- Create: `Source/CDYahooLeaguePlayersResponse.swift`
- Create: `Tests/CDYahooKitTests/Fixtures/LeaguePlayers.xml`
- Modify: `Source/CDYahooRouter.swift` — add `.players(leagueKey:start:)` case
- Modify: `Source/CDYahooFantasyAPIClient.swift` — add `fetchLeaguePlayers(leagueKey:start:)`
- Modify: `Tests/CDYahooKitTests/CDYahooFantasyAPIClientTests.swift` — add the test

**Interfaces:**
- Consumes: `CDYahooPlayer` (Task 16).
- Produces: `public struct CDYahooLeaguePlayersResponse: CDYahooXMLDecodable, Sendable`, `CDYahooFantasyAPIClient.fetchLeaguePlayers(leagueKey: String, start: Int?) async throws -> CDYahooLeaguePlayersResponse`.

- [ ] **Step 1: Create `Tests/CDYahooKitTests/Fixtures/LeaguePlayers.xml`**

```xml
<?xml version="1.0" encoding="UTF-8"?>
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
                <name>
                    <full>Sam Lee</full>
                </name>
                <editorial_team_abbr>NYJ</editorial_team_abbr>
                <display_position>WR</display_position>
                <status/>
            </player>
        </players>
    </league>
</fantasy_content>
```

- [ ] **Step 2: Add the failing test**

```swift
    @Test("fetchLeaguePlayers decodes the league's player pool")
    func fetchLeaguePlayersDecodesFixture() async throws {
        let client = makeClient()
        stubTokenEndpoint()
        try await client.oAuthClient.authorize(withCode: "code", codeVerifier: "verifier")

        CDYahooMockURLProtocol.register(
            stub: .init(statusCode: 200, data: try fixtureData("LeaguePlayers")),
            for: URL(string: "https://fantasysports.yahooapis.com/fantasy/v2/league/449.l.12345/players")!
        )

        let response = try await client.fetchLeaguePlayers(leagueKey: "449.l.12345", start: nil)
        #expect(response.players.count == 2)
        #expect(response.players.first?.status == "ACT")
        #expect(response.players.last?.status == nil)
    }
```

- [ ] **Step 3: Run the test to verify it fails**

Run: `swift test --filter fetchLeaguePlayersDecodesFixture`
Expected: FAIL

- [ ] **Step 4: Add the `.players` case to `Source/CDYahooRouter.swift`**

```swift
        case players(leagueKey: String, start: Int?)
```

and in `path`:

```swift
        case let .players(leagueKey, start):
            if let start {
                "league/\(leagueKey)/players;start=\(start)"
            } else {
                "league/\(leagueKey)/players"
            }
```

- [ ] **Step 5: Write `Source/CDYahooLeaguePlayersResponse.swift`**

```swift
//
//  CDYahooLeaguePlayersResponse.swift
//  CDYahooKit
//

/// The response from `league/{league_key}/players` (optionally `;start={start}` for pagination).
public struct CDYahooLeaguePlayersResponse: CDYahooXMLDecodable, Sendable {
    public let leagueKey: String
    public let players: [CDYahooPlayer]

    init(node: CDYahooXMLNode) throws {
        guard let leagueNode = node.child("league"), let leagueKey = leagueNode.text("league_key") else {
            throw CDYahooXMLDecodingError.missingField("league")
        }
        self.leagueKey = leagueKey
        let playerNodes = leagueNode.child("players")?.children("player") ?? []
        self.players = try playerNodes.map(CDYahooPlayer.init(node:))
    }
}
```

- [ ] **Step 6: Add `fetchLeaguePlayers` to `Source/CDYahooFantasyAPIClient.swift`**

```swift
    /// Fetches a league's player pool. Pass `start` (a zero-based offset) to page through results
    /// beyond Yahoo's default page size; pass `nil` for the first page.
    public func fetchLeaguePlayers(leagueKey: String, start: Int?) async throws -> CDYahooLeaguePlayersResponse {
        let request = try await authorizedRequest(.players(leagueKey: leagueKey, start: start))
        return try await session.perform(request)
    }
```

- [ ] **Step 7: Run the test to verify it passes**

Run: `swift test --filter CDYahooFantasyAPIClientTests`
Expected: PASS

- [ ] **Step 8: Commit**

```bash
git add Source/CDYahooRouter.swift Source/CDYahooFantasyAPIClient.swift Source/CDYahooLeaguePlayersResponse.swift Tests/CDYahooKitTests/Fixtures/LeaguePlayers.xml Tests/CDYahooKitTests/CDYahooFantasyAPIClientTests.swift
git commit -m "feat(fantasy): add fetchLeaguePlayers"
```

---

## Task 18: `fetchLeagueScoreboard`

**Files:**
- Create: `Source/CDYahooLeagueScoreboardResponse.swift`
- Create: `Tests/CDYahooKitTests/Fixtures/LeagueScoreboard.xml`
- Modify: `Source/CDYahooRouter.swift` — add `.scoreboard(leagueKey:week:)` case
- Modify: `Source/CDYahooFantasyAPIClient.swift` — add `fetchLeagueScoreboard(leagueKey:week:)`
- Modify: `Tests/CDYahooKitTests/CDYahooFantasyAPIClientTests.swift` — add the test

**Interfaces:**
- Produces: `public struct CDYahooMatchupTeamScore: CDYahooXMLDecodable, Sendable, Equatable`, `public struct CDYahooMatchup: CDYahooXMLDecodable, Sendable, Equatable`, `public struct CDYahooLeagueScoreboardResponse: CDYahooXMLDecodable, Sendable`, `CDYahooFantasyAPIClient.fetchLeagueScoreboard(leagueKey: String, week: Int?) async throws -> CDYahooLeagueScoreboardResponse`.

- [ ] **Step 1: Create `Tests/CDYahooKitTests/Fixtures/LeagueScoreboard.xml`**

```xml
<?xml version="1.0" encoding="UTF-8"?>
<fantasy_content xml:lang="en-US" time="1.23">
    <league>
        <league_key>449.l.12345</league_key>
        <scoreboard>
            <matchups count="1">
                <matchup>
                    <week>8</week>
                    <status>postevent</status>
                    <teams count="2">
                        <team>
                            <team_key>449.l.12345.t.1</team_key>
                            <name>Team Alpha</name>
                            <team_points>
                                <total>112.5</total>
                            </team_points>
                        </team>
                        <team>
                            <team_key>449.l.12345.t.2</team_key>
                            <name>Team Beta</name>
                            <team_points>
                                <total>98.4</total>
                            </team_points>
                        </team>
                    </teams>
                </matchup>
            </matchups>
        </scoreboard>
    </league>
</fantasy_content>
```

- [ ] **Step 2: Add the failing test**

```swift
    @Test("fetchLeagueScoreboard decodes matchups with each team's points")
    func fetchLeagueScoreboardDecodesFixture() async throws {
        let client = makeClient()
        stubTokenEndpoint()
        try await client.oAuthClient.authorize(withCode: "code", codeVerifier: "verifier")

        CDYahooMockURLProtocol.register(
            stub: .init(statusCode: 200, data: try fixtureData("LeagueScoreboard")),
            for: URL(string: "https://fantasysports.yahooapis.com/fantasy/v2/league/449.l.12345/scoreboard;week=8")!
        )

        let response = try await client.fetchLeagueScoreboard(leagueKey: "449.l.12345", week: 8)
        #expect(response.matchups.count == 1)

        let matchup = try #require(response.matchups.first)
        #expect(matchup.week == 8)
        #expect(matchup.teams.count == 2)
        #expect(matchup.teams.first?.totalPoints == 112.5)
    }
```

- [ ] **Step 3: Run the test to verify it fails**

Run: `swift test --filter fetchLeagueScoreboardDecodesFixture`
Expected: FAIL

- [ ] **Step 4: Add the `.scoreboard` case to `Source/CDYahooRouter.swift`**

```swift
        case scoreboard(leagueKey: String, week: Int?)
```

and in `path`:

```swift
        case let .scoreboard(leagueKey, week):
            if let week {
                "league/\(leagueKey)/scoreboard;week=\(week)"
            } else {
                "league/\(leagueKey)/scoreboard"
            }
```

- [ ] **Step 5: Write `Source/CDYahooLeagueScoreboardResponse.swift`**

```swift
//
//  CDYahooLeagueScoreboardResponse.swift
//  CDYahooKit
//

/// One team's score within a `CDYahooMatchup`.
public struct CDYahooMatchupTeamScore: CDYahooXMLDecodable, Sendable, Equatable {
    public let teamKey: String
    public let name: String
    public let totalPoints: Double?

    init(node: CDYahooXMLNode) throws {
        guard let teamKey = node.text("team_key"), let name = node.text("name") else {
            throw CDYahooXMLDecodingError.missingField("team")
        }
        self.teamKey = teamKey
        self.name = name
        self.totalPoints = node.child("team_points")?.text("total").flatMap(Double.init)
    }
}

/// One head-to-head matchup for a given week.
public struct CDYahooMatchup: CDYahooXMLDecodable, Sendable, Equatable {
    public let week: Int
    public let status: String
    public let teams: [CDYahooMatchupTeamScore]

    init(node: CDYahooXMLNode) throws {
        self.week = node.int("week") ?? 0
        self.status = node.text("status") ?? ""
        let teamNodes = node.child("teams")?.children("team") ?? []
        self.teams = try teamNodes.map(CDYahooMatchupTeamScore.init(node:))
    }
}

/// The response from `league/{league_key}/scoreboard` (optionally `;week={week}`).
public struct CDYahooLeagueScoreboardResponse: CDYahooXMLDecodable, Sendable {
    public let leagueKey: String
    public let matchups: [CDYahooMatchup]

    init(node: CDYahooXMLNode) throws {
        guard let leagueNode = node.child("league"), let leagueKey = leagueNode.text("league_key") else {
            throw CDYahooXMLDecodingError.missingField("league")
        }
        self.leagueKey = leagueKey
        let matchupNodes = leagueNode.child("scoreboard")?.child("matchups")?.children("matchup") ?? []
        self.matchups = try matchupNodes.map(CDYahooMatchup.init(node:))
    }
}
```

- [ ] **Step 6: Add `fetchLeagueScoreboard` to `Source/CDYahooFantasyAPIClient.swift`**

```swift
    /// Fetches a league's scoreboard (every matchup) for a week. Pass `nil` for the current week.
    public func fetchLeagueScoreboard(leagueKey: String, week: Int?) async throws -> CDYahooLeagueScoreboardResponse {
        let request = try await authorizedRequest(.scoreboard(leagueKey: leagueKey, week: week))
        return try await session.perform(request)
    }
```

- [ ] **Step 7: Run the test to verify it passes**

Run: `swift test --filter CDYahooFantasyAPIClientTests`
Expected: PASS

- [ ] **Step 8: Commit**

```bash
git add Source/CDYahooRouter.swift Source/CDYahooFantasyAPIClient.swift Source/CDYahooLeagueScoreboardResponse.swift Tests/CDYahooKitTests/Fixtures/LeagueScoreboard.xml Tests/CDYahooKitTests/CDYahooFantasyAPIClientTests.swift
git commit -m "feat(fantasy): add fetchLeagueScoreboard"
```

---

## Task 19: `fetchLeagueTransactions`

**Files:**
- Create: `Source/CDYahooLeagueTransactionsResponse.swift`
- Create: `Tests/CDYahooKitTests/Fixtures/LeagueTransactions.xml`
- Modify: `Source/CDYahooRouter.swift` — add `.transactions(leagueKey:)` case
- Modify: `Source/CDYahooFantasyAPIClient.swift` — add `fetchLeagueTransactions(leagueKey:)`
- Modify: `Tests/CDYahooKitTests/CDYahooFantasyAPIClientTests.swift` — add the test

**Interfaces:**
- Produces: `public struct CDYahooTransactionPlayer: CDYahooXMLDecodable, Sendable, Equatable`, `public struct CDYahooTransaction: CDYahooXMLDecodable, Sendable, Equatable`, `public struct CDYahooLeagueTransactionsResponse: CDYahooXMLDecodable, Sendable`, `CDYahooFantasyAPIClient.fetchLeagueTransactions(leagueKey: String) async throws -> CDYahooLeagueTransactionsResponse`.

- [ ] **Step 1: Create `Tests/CDYahooKitTests/Fixtures/LeagueTransactions.xml`**

```xml
<?xml version="1.0" encoding="UTF-8"?>
<fantasy_content xml:lang="en-US" time="1.23">
    <league>
        <league_key>449.l.12345</league_key>
        <transactions count="1">
            <transaction>
                <transaction_key>449.l.12345.tr.1</transaction_key>
                <transaction_id>1</transaction_id>
                <type>add/drop</type>
                <status>successful</status>
                <players>
                    <player>
                        <player_key>449.p.30789</player_key>
                        <name>
                            <full>Sam Lee</full>
                        </name>
                        <transaction_data>
                            <type>add</type>
                            <destination_team_key>449.l.12345.t.1</destination_team_key>
                        </transaction_data>
                    </player>
                </players>
            </transaction>
        </transactions>
    </league>
</fantasy_content>
```

- [ ] **Step 2: Add the failing test**

```swift
    @Test("fetchLeagueTransactions decodes transactions and the players they moved")
    func fetchLeagueTransactionsDecodesFixture() async throws {
        let client = makeClient()
        stubTokenEndpoint()
        try await client.oAuthClient.authorize(withCode: "code", codeVerifier: "verifier")

        CDYahooMockURLProtocol.register(
            stub: .init(statusCode: 200, data: try fixtureData("LeagueTransactions")),
            for: URL(string: "https://fantasysports.yahooapis.com/fantasy/v2/league/449.l.12345/transactions")!
        )

        let response = try await client.fetchLeagueTransactions(leagueKey: "449.l.12345")
        #expect(response.transactions.count == 1)

        let transaction = try #require(response.transactions.first)
        #expect(transaction.type == "add/drop")
        #expect(transaction.players.first?.fullName == "Sam Lee")
        #expect(transaction.players.first?.transactionType == "add")
    }
```

- [ ] **Step 3: Run the test to verify it fails**

Run: `swift test --filter fetchLeagueTransactionsDecodesFixture`
Expected: FAIL

- [ ] **Step 4: Add the `.transactions` case to `Source/CDYahooRouter.swift`**

```swift
        case transactions(leagueKey: String)
```

and in `path`:

```swift
        case let .transactions(leagueKey):
            "league/\(leagueKey)/transactions"
```

- [ ] **Step 5: Write `Source/CDYahooLeagueTransactionsResponse.swift`**

```swift
//
//  CDYahooLeagueTransactionsResponse.swift
//  CDYahooKit
//

/// A player as they appear inside one transaction, with the move that was made.
public struct CDYahooTransactionPlayer: CDYahooXMLDecodable, Sendable, Equatable {
    public let playerKey: String
    public let fullName: String
    public let transactionType: String?
    public let destinationTeamKey: String?

    init(node: CDYahooXMLNode) throws {
        guard let playerKey = node.text("player_key"), let fullName = node.child("name")?.text("full") else {
            throw CDYahooXMLDecodingError.missingField("player")
        }
        self.playerKey = playerKey
        self.fullName = fullName
        let transactionData = node.child("transaction_data")
        self.transactionType = transactionData?.text("type")
        self.destinationTeamKey = transactionData?.text("destination_team_key")
    }
}

/// A single league transaction (add/drop, trade, or waiver claim).
public struct CDYahooTransaction: CDYahooXMLDecodable, Sendable, Equatable {
    public let transactionKey: String
    public let transactionId: String
    public let type: String
    public let status: String
    public let players: [CDYahooTransactionPlayer]

    init(node: CDYahooXMLNode) throws {
        guard let transactionKey = node.text("transaction_key"), let transactionId = node.text("transaction_id"),
              let type = node.text("type"), let status = node.text("status") else {
            throw CDYahooXMLDecodingError.missingField("transaction")
        }
        self.transactionKey = transactionKey
        self.transactionId = transactionId
        self.type = type
        self.status = status
        let playerNodes = node.child("players")?.children("player") ?? []
        self.players = try playerNodes.map(CDYahooTransactionPlayer.init(node:))
    }
}

/// The response from `league/{league_key}/transactions`.
public struct CDYahooLeagueTransactionsResponse: CDYahooXMLDecodable, Sendable {
    public let leagueKey: String
    public let transactions: [CDYahooTransaction]

    init(node: CDYahooXMLNode) throws {
        guard let leagueNode = node.child("league"), let leagueKey = leagueNode.text("league_key") else {
            throw CDYahooXMLDecodingError.missingField("league")
        }
        self.leagueKey = leagueKey
        let transactionNodes = leagueNode.child("transactions")?.children("transaction") ?? []
        self.transactions = try transactionNodes.map(CDYahooTransaction.init(node:))
    }
}
```

- [ ] **Step 6: Add `fetchLeagueTransactions` to `Source/CDYahooFantasyAPIClient.swift`**

```swift
    /// Fetches a league's transaction history (adds, drops, trades, waiver claims).
    public func fetchLeagueTransactions(leagueKey: String) async throws -> CDYahooLeagueTransactionsResponse {
        let request = try await authorizedRequest(.transactions(leagueKey: leagueKey))
        return try await session.perform(request)
    }
```

- [ ] **Step 7: Run the full suite to verify everything passes**

Run: `swift test`
Expected: PASS — every test written across Tasks 1-19

- [ ] **Step 8: Commit**

```bash
git add Source/CDYahooRouter.swift Source/CDYahooFantasyAPIClient.swift Source/CDYahooLeagueTransactionsResponse.swift Tests/CDYahooKitTests/Fixtures/LeagueTransactions.xml Tests/CDYahooKitTests/CDYahooFantasyAPIClientTests.swift
git commit -m "feat(fantasy): add fetchLeagueTransactions"
```

---

## Task 20: Xcode project/workspace and Example app sign-in flow

**Files:**
- Create: `CDYahooKit.xcodeproj` + `CDYahooKit.xcworkspace` (via Xcode, not hand-authored — see Step 1)
- Create: `Example/CDYahooKit.xcodeproj` (or a single root-level Example scheme — match whichever CDOAuth1Kit's structure uses; confirm by opening `/Users/christopherdehaan/Documents/Workspaces/GitHub/CDOAuth1Kit` in Xcode before starting this task)
- Create: `Example/Resources/Info.plist`, `Example/Resources/Assets.xcassets`
- Create: `Example/Secrets.xcconfig.example`
- Create: `Example/Source/AppDelegate.swift`, `Example/Source/SceneDelegate.swift`, `Example/Source/ViewController.swift`
- Modify: `.gitignore` — already excludes `Example/Secrets.xcconfig` (done in Task 2)

**Interfaces:**
- Consumes: `CDYahooFantasyAPIClient`, `CDYahooAuthSession`, `CDYahooPKCE` (Tasks 9-13).
- Produces: a runnable iOS example app with a "Sign In With Yahoo" button.

This task is Xcode-GUI-driven rather than fully scriptable — `.pbxproj`/`.xcworkspacedata` files aren't meant to be hand-typed. Steps describe what to configure in Xcode; there is no red/green test cycle for project-file creation itself, but the app must actually run before this task is done.

- [ ] **Step 1: Open the SPM package in Xcode and generate the workspace**

Open `Package.swift` in Xcode (`xed .` from the repo root). Xcode auto-generates a `.swiftpm`-backed workspace when you do this; to get a checked-in `CDYahooKit.xcworkspace` matching CDOAuth1Kit's structure, instead: File → New → Project → iOS → App, save it as `Example/iOS Example.xcodeproj` inside the repo, then File → New → Workspace, save as `CDYahooKit.xcworkspace` at the repo root, and drag both `Package.swift` (as a local Swift package reference) and `Example/iOS Example.xcodeproj` into it — mirroring `CDOAuth1Kit.xcworkspace`'s contents (open `/Users/christopherdehaan/Documents/Workspaces/GitHub/CDOAuth1Kit/CDOAuth1Kit.xcworkspace/contents.xcworkspacedata` as a reference for the exact file references to add).

- [ ] **Step 2: Configure the Example app target**

- Product name: "iOS Example", bundle identifier `me.christopherdehaan.CDYahooKit.Example`
- Deployment target: iOS 15.0
- Interface: SwiftUI or Storyboard, your choice — CDOAuth1Kit's example uses a Storyboard-based `ViewController`; match that for consistency
- Add `CDYahooKit` as a local Swift Package dependency of the Example target (Xcode → target → General → Frameworks, Libraries, and Embedded Content → + → Add Package Dependency → Add Local...)
- Register a custom URL scheme in the target's Info tab (URL Types) — e.g. `cdyahookitexample` — matching what you'll register as the redirect URI on the Yahoo Developer Network app

- [ ] **Step 3: Create `Example/Secrets.xcconfig.example`**

```
// Copy this file to Secrets.xcconfig (gitignored) and fill in your own values
// from https://developer.yahoo.com/apps/
YAHOO_CLIENT_ID = your-client-id-here
YAHOO_CLIENT_SECRET = your-client-secret-here
YAHOO_REDIRECT_URL = cdyahookitexample://callback
```

Reference `Secrets.xcconfig` from the Example target's build settings (Configurations → Debug/Release → Based on Configuration File), the same way CDOAuth1Kit's Example does — check `/Users/christopherdehaan/Documents/Workspaces/GitHub/CDOAuth1Kit/Example/Secrets.xcconfig.example` for the exact key names and wiring pattern to mirror.

- [ ] **Step 4: Write `Example/Source/ViewController.swift`**

```swift
//
//  ViewController.swift
//  iOS Example
//

import AuthenticationServices
import CDYahooKit
import UIKit

final class ViewController: UIViewController {

    private let client = CDYahooFantasyAPIClient(
        clientId: Bundle.main.object(forInfoDictionaryKey: "YAHOO_CLIENT_ID") as? String ?? "",
        clientSecret: Bundle.main.object(forInfoDictionaryKey: "YAHOO_CLIENT_SECRET") as? String ?? "",
        redirectUrl: Bundle.main.object(forInfoDictionaryKey: "YAHOO_REDIRECT_URL") as? String ?? ""
    )

    private var pendingCodeVerifier: String?
    private var pendingState: String?

    @IBAction private func signInTapped(_ sender: UIButton) {
        Task { await signIn() }
    }

    @MainActor
    private func signIn() async {
        let verifier = CDYahooPKCE.makeCodeVerifier()
        let challenge = CDYahooPKCE.codeChallenge(for: verifier)
        let state = UUID().uuidString
        pendingCodeVerifier = verifier
        pendingState = state

        do {
            let authURL = try client.oAuthClient.authorizationURL(codeChallenge: challenge, state: state)
            let callback = try await CDYahooAuthSession(presentationAnchor: view.window!)
                .authorize(authorizationURL: authURL, callbackScheme: "cdyahookitexample")
            let code = try CDYahooAuthSession.extractCode(from: callback, expectedState: state)
            try await client.oAuthClient.authorize(withCode: code, codeVerifier: verifier)
            let games = try await client.fetchUserGames()
            print("Signed in. Leagues: \(games.games.flatMap(\.leagues).map(\.name))")
        } catch {
            print("Sign in failed: \(error)")
        }
    }
}
```

- [ ] **Step 5: Verify the app runs**

Build and run the "iOS Example" scheme in the simulator. Tapping "Sign In With Yahoo" should present the `ASWebAuthenticationSession` browser sheet pointed at `api.login.yahoo.com`. (Completing a real sign-in requires a Yahoo Developer Network app registration — out of scope to automate, but the sheet presenting correctly confirms the URL/PKCE/callback-scheme wiring is correct.)

- [ ] **Step 6: Commit**

```bash
git add CDYahooKit.xcworkspace "Example/iOS Example.xcodeproj" Example/Source Example/Resources Example/Secrets.xcconfig.example
git commit -m "feat(example): add Xcode workspace and Sign In With Yahoo example app"
```

---

## Task 21: Example app league/standings screen

**Files:**
- Create: `Example/Source/LeagueListViewController.swift`
- Create: `Example/Source/StandingsViewController.swift`
- Modify: `Example/Source/ViewController.swift` — push `LeagueListViewController` on successful sign-in instead of just printing
- Modify: `Example/Resources/Base.lproj/Main.storyboard` (or SwiftUI equivalent) — add the two new screens

**Interfaces:**
- Consumes: `CDYahooFantasyAPIClient.fetchUserGames`, `.fetchLeagueStandings` (Tasks 13, 15).

- [ ] **Step 1: Write `Example/Source/LeagueListViewController.swift`**

```swift
//
//  LeagueListViewController.swift
//  iOS Example
//

import CDYahooKit
import UIKit

final class LeagueListViewController: UITableViewController {

    var client: CDYahooFantasyAPIClient!
    private var leagues: [CDYahooLeagueSummary] = []

    override func viewDidLoad() {
        super.viewDidLoad()
        title = "Your Leagues"
        Task { await loadLeagues() }
    }

    @MainActor
    private func loadLeagues() async {
        do {
            let response = try await client.fetchUserGames()
            leagues = response.games.flatMap(\.leagues)
            tableView.reloadData()
        } catch {
            print("Failed to load leagues: \(error)")
        }
    }

    override func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        leagues.count
    }

    override func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        let cell = UITableViewCell(style: .default, reuseIdentifier: nil)
        cell.textLabel?.text = leagues[indexPath.row].name
        return cell
    }

    override func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        let standingsViewController = StandingsViewController()
        standingsViewController.client = client
        standingsViewController.leagueKey = leagues[indexPath.row].leagueKey
        navigationController?.pushViewController(standingsViewController, animated: true)
    }
}
```

- [ ] **Step 2: Write `Example/Source/StandingsViewController.swift`**

```swift
//
//  StandingsViewController.swift
//  iOS Example
//

import CDYahooKit
import UIKit

final class StandingsViewController: UITableViewController {

    var client: CDYahooFantasyAPIClient!
    var leagueKey: String!
    private var teams: [CDYahooTeamStanding] = []

    override func viewDidLoad() {
        super.viewDidLoad()
        title = "Standings"
        Task { await loadStandings() }
    }

    @MainActor
    private func loadStandings() async {
        do {
            let response = try await client.fetchLeagueStandings(leagueKey: leagueKey)
            teams = response.teams.sorted { ($0.rank ?? .max) < ($1.rank ?? .max) }
            tableView.reloadData()
        } catch {
            print("Failed to load standings: \(error)")
        }
    }

    override func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        teams.count
    }

    override func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        let team = teams[indexPath.row]
        let cell = UITableViewCell(style: .subtitle, reuseIdentifier: nil)
        cell.textLabel?.text = "\(team.rank.map { "#\($0) " } ?? "")\(team.name)"
        if let outcomeTotals = team.outcomeTotals {
            cell.detailTextLabel?.text = "\(outcomeTotals.wins)-\(outcomeTotals.losses)-\(outcomeTotals.ties)"
        }
        return cell
    }
}
```

- [ ] **Step 3: Update `Example/Source/ViewController.swift`**

Replace the `print("Signed in. Leagues: ...")` line in `signIn()` with pushing the new screen:

```swift
            try await client.oAuthClient.authorize(withCode: code, codeVerifier: verifier)
            let leagueListViewController = LeagueListViewController()
            leagueListViewController.client = client
            navigationController?.pushViewController(leagueListViewController, animated: true)
```

- [ ] **Step 4: Verify in the simulator**

Run the "iOS Example" scheme, sign in (requires a real Yahoo Developer Network app registration and at least one fantasy league on the signed-in account), and confirm the league list loads, tapping a league shows its standings.

- [ ] **Step 5: Commit**

```bash
git add Example/Source/LeagueListViewController.swift Example/Source/StandingsViewController.swift Example/Source/ViewController.swift
git commit -m "feat(example): add league list and standings screens"
```

---

## Task 22: DocC catalog and usage documentation

**Files:**
- Create: `Source/CDYahooKit.docc/CDYahooKit.md`
- Create: `Source/CDYahooKit.docc/GettingStarted.md`
- Create: `Documentation/Usage.md`
- Create: `Documentation/ARCHITECTURE.md`
- Modify: `Package.swift` — add the `swift-docc-plugin` dependency

**Interfaces:**
- None — documentation only.

- [ ] **Step 1: Add the DocC plugin dependency to `Package.swift`**

```swift
    dependencies: [
        .package(url: "https://github.com/apple/swift-docc-plugin", from: "1.3.0")
    ],
```

- [ ] **Step 2: Write `Source/CDYahooKit.docc/CDYahooKit.md`**

```markdown
# ``CDYahooKit``

A Swift wrapper for the Yahoo Fantasy Sports API, with Sign In With Yahoo (OAuth 2.0 / PKCE)
for authentication.

## Overview

CDYahooKit covers the Yahoo Fantasy Sports API's read-only endpoints — a user's games and
leagues, league metadata, standings, team rosters, the league player pool, the weekly
scoreboard, and league transactions — plus the OAuth 2.0 handshake needed to call them.

Yahoo Fantasy Sports API responses are XML, not JSON; CDYahooKit parses them directly rather
than going through Yahoo's `format=json` parameter, whose output is known to be inconsistent.
See ``CDYahooXMLNode`` and ``CDYahooXMLDecodable`` for how.

## Topics

### Getting Started

- <doc:GettingStarted>

### Fantasy Sports API

- ``CDYahooFantasyAPIClient``
- ``CDYahooGame``
- ``CDYahooLeague``
- ``CDYahooTeamStanding``
- ``CDYahooPlayer``
- ``CDYahooMatchup``
- ``CDYahooTransaction``

### Authentication

- ``CDYahooOAuthClient``
- ``CDYahooAuthSession``
- ``CDYahooPKCE``

### Errors

- ``CDYahooKitError``
```

- [ ] **Step 3: Write `Source/CDYahooKit.docc/GettingStarted.md`**

```markdown
# Getting Started

Register an app at the [Yahoo Developer Network](https://developer.yahoo.com/apps/), then
authenticate and fetch data.

## Registering Your App

Create an app at `developer.yahoo.com/apps/`, request Fantasy Sports read access, and note
your Client ID, Client Secret, and redirect URI (a custom URL scheme, e.g. `myapp://callback`).

## Authenticating

```swift
import CDYahooKit

let client = CDYahooFantasyAPIClient(clientId: "...", clientSecret: "...", redirectUrl: "myapp://callback")

let verifier = CDYahooPKCE.makeCodeVerifier()
let challenge = CDYahooPKCE.codeChallenge(for: verifier)
let state = UUID().uuidString
let authURL = try client.oAuthClient.authorizationURL(codeChallenge: challenge, state: state)

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
```

- [ ] **Step 4: Write `Documentation/Usage.md`**

```markdown
# Usage

## Installation

Add CDYahooKit to your `Package.swift`:

```swift
.package(url: "https://github.com/chrisdhaan/CDYahooKit.git", from: "1.0.0")
```

Or in Xcode: File → Add Packages → Enter `https://github.com/chrisdhaan/CDYahooKit.git`

## Scope

CDYahooKit wraps the Yahoo Fantasy Sports API only — see the design spec
(`docs/superpowers/specs/2026-08-24-cdyahookit-fantasy-sports-rewrite-design.md`) for why
every other Yahoo developer API this library once targeted (Social, YQL, Weather, Finance,
BOSS) has since been shut down.

v1 is read-only. Write endpoints (roster/lineup changes, waiver claims, trades) aren't covered.

## Authentication, Fetching Data, Testing

See <doc:GettingStarted> in the DocC catalog for a full walkthrough, and `CDYahooKitTesting`'s
`CDYahooMockURLProtocol` for mocking network calls in your own app's tests.
```

- [ ] **Step 5: Write `Documentation/ARCHITECTURE.md`**

```markdown
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
```

- [ ] **Step 6: Verify the DocC build**

Run: `swift package --disable-sandbox generate-documentation --target CDYahooKit`
Expected: succeeds with no errors (warnings about missing symbol documentation are acceptable at this stage but should be minimized)

- [ ] **Step 7: Commit**

```bash
git add Package.swift Source/CDYahooKit.docc Documentation
git commit -m "docs: add DocC catalog and usage/architecture documentation"
```

---

## Task 23: README, CHANGELOG, full CI platform matrix, and generate-docs script

**Files:**
- Modify: `README.md` — rewrite for the Swift/SPM package
- Create: `CHANGELOG.md`
- Modify: `.github/workflows/ci.yml` — add the iOS/macOS/tvOS/watchOS/visionOS/Catalyst `xcodebuild` matrix jobs, DocC build job, CodeQL job (now that Task 20 created the Xcode workspace/project and schemes)
- Create: `scripts/generate-docs.sh`

**Interfaces:**
- None — release/tooling polish.

- [ ] **Step 1: Rewrite `README.md`**

```markdown
# CDYahooKit

[![CI Status](https://github.com/chrisdhaan/CDYahooKit/actions/workflows/ci.yml/badge.svg)](https://github.com/chrisdhaan/CDYahooKit/actions/workflows/ci.yml)
[![Swift](https://img.shields.io/badge/Swift-6.0%2B-orange?style=flat)](https://swift.org)
[![SPM](https://img.shields.io/badge/Swift_Package_Manager-compatible-orange?style=flat)](https://swift.org/package-manager/)
[![License](https://img.shields.io/badge/License-MIT-blue.svg?style=flat)](LICENSE)

---

A Swift wrapper for the Yahoo Fantasy Sports API, with Sign In With Yahoo (OAuth 2.0 / PKCE)
for authentication. No external dependencies.

## Features

- [x] Yahoo Fantasy Sports API: games, leagues, standings, rosters, players, scoreboard, transactions (read-only)
- [x] Sign In With Yahoo: OAuth 2.0 authorization code flow with PKCE
- [x] Keychain-backed token storage with silent refresh
- [x] async/await API
- [x] Zero external dependencies

## Requirements

| Platform | Minimum OS | Swift | Installation |
|----------|-----------|-------|--------------|
| iOS      | 15.0+     | 6.0+  | SPM          |
| macOS    | 12.0+     | 6.0+  | SPM          |
| tvOS     | 15.0+     | 6.0+  | SPM          |
| watchOS  | 8.0+      | 6.0+  | SPM          |
| visionOS | 1.0+      | 6.0+  | SPM          |

## Installation

### Swift Package Manager

Add CDYahooKit to your `Package.swift`:

```swift
.package(url: "https://github.com/chrisdhaan/CDYahooKit.git", from: "1.0.0")
```

Or in Xcode: File → Add Packages → Enter `https://github.com/chrisdhaan/CDYahooKit.git`

## Usage

See [Documentation/Usage.md](Documentation/Usage.md) for comprehensive usage examples, or browse
the full [API documentation](https://chrisdhaan.github.io/CDYahooKit/documentation/cdyahookit/).

## Example App

The `Example/` app demonstrates the full OAuth 2.0 handshake and fetches the signed-in user's
fantasy leagues and standings. It reads its Yahoo `clientId`/`clientSecret`/`redirectUrl` from
`Example/Secrets.xcconfig` (gitignored). Before building it:

```bash
cp "Example/Secrets.xcconfig.example" "Example/Secrets.xcconfig"
```

Then edit `Secrets.xcconfig` with your own credentials from the
[Yahoo Developer Network](https://developer.yahoo.com/apps/). Open `CDYahooKit.xcworkspace` and
run the `iOS Example` scheme.

## Scope

CDYahooKit wraps the Yahoo Fantasy Sports API only. Every other Yahoo developer API this
library once targeted (Social, YQL, Weather, Finance, BOSS) has since been shut down — see
`docs/superpowers/specs/2026-08-24-cdyahookit-fantasy-sports-rewrite-design.md` for the audit.

## Author

Christopher de Haan, contact@christopherdehaan.me

## License

CDYahooKit is available under the MIT license. See the LICENSE file for more info.
```

- [ ] **Step 2: Create `CHANGELOG.md`**

```markdown
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
```

- [ ] **Step 3: Add the full platform CI matrix to `.github/workflows/ci.yml`**

Append the `iOS`, `macOS`, `tvOS`, `watchOS`, `visionOS`, `Catalyst`, `documentation`, and
`codeql` jobs from CDUntappdKit's `.github/workflows/ci.yml`
(`/Users/christopherdehaan/Documents/Workspaces/GitHub/CDUntappdKit/.github/workflows/ci.yml`),
substituting every `CDUntappdKit` project/scheme reference for `CDYahooKit`/`iOS Example` (the
scheme names Task 20 actually created), and every `--target CDUntappdKit` for
`--target CDYahooKit`. Keep the `on:`/`concurrency:` block and the existing `SPM`/`swiftlint`/
`swiftformat` jobs from Task 2 unchanged.

- [ ] **Step 4: Create `scripts/generate-docs.sh`**

```bash
#!/bin/bash
set -euo pipefail

# Regenerates docs/ from the CDYahooKit DocC catalog for GitHub Pages hosting.

swift package --disable-sandbox generate-documentation \
    --target CDYahooKit \
    --output-path docs \
    --transform-for-static-hosting \
    --hosting-base-path CDYahooKit

touch docs/.nojekyll

cat > docs/index.html <<'EOF'
<!DOCTYPE html>
<html>
  <head>
    <meta http-equiv="refresh" content="0; url=documentation/cdyahookit/" />
  </head>
  <body></body>
</html>
EOF

cat > docs/404.html <<'EOF'
<!DOCTYPE html>
<html>
  <head>
    <meta http-equiv="refresh" content="0; url=/CDYahooKit/documentation/cdyahookit/" />
  </head>
  <body></body>
</html>
EOF

echo "Documentation generated at docs/"
```

```bash
chmod +x scripts/generate-docs.sh
```

- [ ] **Step 5: Run the doc generation script and verify output**

Run: `bash scripts/generate-docs.sh`
Expected: `docs/index.html`, `docs/404.html`, `docs/.nojekyll`, and `docs/documentation/cdyahookit/` all exist afterward

- [ ] **Step 6: Verify CI locally where possible**

Run: `swift build && swift test && swiftlint lint --strict` (skip `swiftformat`/`xcodebuild` steps if those tools aren't installed locally — CI will catch any remaining issues)
Expected: all succeed

- [ ] **Step 7: Commit**

```bash
git add README.md CHANGELOG.md .github/workflows/ci.yml scripts/generate-docs.sh docs
git commit -m "docs: rewrite README, add CHANGELOG, full CI platform matrix, and doc generation script"
```

---

## Post-plan follow-ups (explicitly out of scope for this plan)

- Write endpoints (lineup changes, add/drop, waiver claims, trades) — a v2 spec once this
  read-side XML layer has shipped and proven itself, per the design spec.
- A shared `CDOAuth2Kit` package — revisit only if a second OAuth2-based sibling kit appears.
- CI matrix pruning/expansion to match whatever Xcode versions are current when this plan is
  actually executed (Task 23's job list mirrors CDUntappdKit's as of 2026-08-24; Xcode version
  availability drifts).
