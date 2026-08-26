//
//  LeagueListViewController.swift
//  iOS Example
//

import CDYahooKit
import UIKit

/// Lists every fantasy league the signed-in user has a team in, fetched via
/// `CDYahooFantasyAPIClient.fetchUserGames()`. Selecting a league pushes its standings.
final class LeagueListViewController: UITableViewController {

    var client: CDYahooFantasyAPIClient!

    private var leagues: [CDYahooLeagueSummary] = []

    private static let cellReuseIdentifier = "LeagueCell"

    override func viewDidLoad() {
        super.viewDidLoad()

        title = "Leagues"
        tableView.register(UITableViewCell.self, forCellReuseIdentifier: Self.cellReuseIdentifier)

        Task { await loadLeagues() }
    }

    private func loadLeagues() async {
        do {
            let response = try await client.fetchUserGames()
            leagues = response.games.flatMap(\.leagues)
            tableView.reloadData()
        } catch {
            print("Failed to fetch leagues: \(error)")
        }
    }

    override func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        leagues.count
    }

    override func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        let cell = tableView.dequeueReusableCell(withIdentifier: Self.cellReuseIdentifier, for: indexPath)
        cell.textLabel?.text = leagues[indexPath.row].name
        cell.accessoryType = .disclosureIndicator
        return cell
    }

    override func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        tableView.deselectRow(at: indexPath, animated: true)

        let standingsViewController = StandingsViewController()
        standingsViewController.client = client
        standingsViewController.leagueKey = leagues[indexPath.row].leagueKey
        navigationController?.pushViewController(standingsViewController, animated: true)
    }
}
