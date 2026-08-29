//
//  ViewController.swift
//  iOS Example
//

import CDYahooKit
import UIKit

/// The Example's root screen: a list with a Sign In With Yahoo row and one row per read-only
/// Fantasy Sports API resource. Tapping an endpoint row runs the request through
/// ``CDYahooKitManager`` and pushes a ``CDYahooKitXMLResponseViewController`` showing the raw
/// XML Yahoo returned; failures surface in an alert.
final class ViewController: UITableViewController {

    private enum Row: Int, CaseIterable {
        case signIn
        case userGames
        case league
        case standings
        case teamRoster
        case leaguePlayers
        case scoreboard
        case transactions
        case settings
        case leagueDraftResults
        case teamDraftResults
        case teamMatchups
        case teamStats

        var title: String {
            switch self {
            case .signIn: "Sign In With Yahoo"
            case .userGames: "User Games & Leagues"
            case .league: "League Metadata"
            case .standings: "League Standings"
            case .teamRoster: "Team Roster"
            case .leaguePlayers: "League Players"
            case .scoreboard: "League Scoreboard"
            case .transactions: "League Transactions"
            case .settings: "League Settings"
            case .leagueDraftResults: "League Draft Results"
            case .teamDraftResults: "Team Draft Results"
            case .teamMatchups: "Team Matchups"
            case .teamStats: "Team Stats"
            }
        }

        /// Every row except Sign In needs an access token first.
        var requiresAuthorization: Bool { self != .signIn }
    }

    private static let cellReuseIdentifier = "CDYahooKitEndpointCell"

    init() {
        super.init(style: .insetGrouped)
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    override func viewDidLoad() {
        super.viewDidLoad()

        title = "CDYahooKit Example"
        tableView.register(UITableViewCell.self, forCellReuseIdentifier: Self.cellReuseIdentifier)

        Task {
            await CDYahooKitManager.shared.start()
            tableView.reloadData()
        }
    }

    // MARK: - UITableViewDataSource

    override func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        Row.allCases.count
    }

    override func tableView(_ tableView: UITableView, titleForHeaderInSection section: Int) -> String? {
        "Fantasy Sports API"
    }

    override func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        let cell = tableView.dequeueReusableCell(withIdentifier: Self.cellReuseIdentifier, for: indexPath)
        guard let row = Row(rawValue: indexPath.row) else { return cell }

        let signedIn = CDYahooKitManager.shared.isSignedIn
        let enabled = !row.requiresAuthorization || signedIn

        var content = cell.defaultContentConfiguration()
        content.text = row == .signIn && signedIn ? "Sign Out" : row.title
        content.textProperties.color = enabled ? .label : .tertiaryLabel
        cell.contentConfiguration = content
        cell.selectionStyle = enabled ? .default : .none
        cell.accessoryType = row.requiresAuthorization ? .disclosureIndicator : .none

        return cell
    }

    // MARK: - UITableViewDelegate

    override func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        tableView.deselectRow(at: indexPath, animated: true)
        guard let row = Row(rawValue: indexPath.row) else { return }

        switch row {
        case .signIn:
            if CDYahooKitManager.shared.isSignedIn {
                signOut()
            } else {
                signIn()
            }
        default:
            guard CDYahooKitManager.shared.isSignedIn else {
                presentAlert(title: "Not Signed In", message: "Tap \"Sign In With Yahoo\" first.")
                return
            }
            runEndpoint(row)
        }
    }
}

// MARK: - Sign In

private extension ViewController {

    func signIn() {
        guard let window = view.window else { return }
        Task {
            do {
                try await CDYahooKitManager.shared.signIn(presentationAnchor: window)
                tableView.reloadData()
            } catch CDYahooKitError.authorizationCancelled {
                // User dismissed the browser sheet; nothing to report.
            } catch {
                presentAlert(title: "Sign In Failed", message: "\(error)")
            }
        }
    }

    func signOut() {
        Task {
            await CDYahooKitManager.shared.signOut()
            tableView.reloadData()
        }
    }
}

// MARK: - Endpoint Requests

private extension ViewController {

    private func runEndpoint(_ row: Row) {
        Task {
            do {
                try await performFetch(for: row)
                showLastResponse(title: row.title)
            } catch {
                presentAlert(title: "Request Failed", message: "\(error)")
            }
        }
    }

    private func performFetch(for row: Row) async throws {
        let manager = CDYahooKitManager.shared
        let client = manager.client!

        switch row {
        case .signIn:
            break
        case .userGames:
            _ = try await client.fetchUserGames()
        case .teamRoster:
            _ = try await client.fetchTeamRoster(teamKey: manager.requireTeamKey(), week: nil)
        case .teamDraftResults:
            _ = try await client.fetchTeamDraftResults(teamKey: manager.requireTeamKey())
        case .teamMatchups:
            _ = try await client.fetchTeamMatchups(teamKey: manager.requireTeamKey())
        case .teamStats:
            _ = try await client.fetchTeamStats(teamKey: manager.requireTeamKey())
        default:
            try await performLeagueFetch(for: row, client: client, leagueKey: manager.requireLeagueKey())
        }
    }

    /// The `league/{leagueKey}/…` endpoints, split out of `performFetch(for:)` so neither switch
    /// trips SwiftLint's cyclomatic-complexity limit as the endpoint list grows.
    private func performLeagueFetch(for row: Row, client: CDYahooFantasyAPIClient, leagueKey: String) async throws {
        switch row {
        case .league:
            _ = try await client.fetchLeague(leagueKey: leagueKey)
        case .standings:
            _ = try await client.fetchLeagueStandings(leagueKey: leagueKey)
        case .leaguePlayers:
            _ = try await client.fetchLeaguePlayers(leagueKey: leagueKey, start: nil)
        case .scoreboard:
            _ = try await client.fetchLeagueScoreboard(leagueKey: leagueKey, week: nil)
        case .transactions:
            _ = try await client.fetchLeagueTransactions(leagueKey: leagueKey)
        case .settings:
            _ = try await client.fetchLeagueSettings(leagueKey: leagueKey)
        case .leagueDraftResults:
            _ = try await client.fetchLeagueDraftResults(leagueKey: leagueKey)
        case .signIn, .userGames, .teamRoster, .teamDraftResults, .teamMatchups, .teamStats:
            break
        }
    }

    func showLastResponse(title: String) {
        guard let xml = CDYahooKitManager.shared.lastResponseXML else {
            presentAlert(title: "No Response", message: "The request completed but no response body was captured.")
            return
        }
        let responseViewController = CDYahooKitXMLResponseViewController(title: title, xmlText: xml)
        navigationController?.pushViewController(responseViewController, animated: true)
    }

    func presentAlert(title: String, message: String) {
        let alertController = UIAlertController(title: title, message: message, preferredStyle: .alert)
        alertController.addAction(UIAlertAction(title: "OK", style: .default, handler: nil))
        present(alertController, animated: true, completion: nil)
    }
}
