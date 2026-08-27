//
//  StandingsViewController.swift
//  iOS Example
//

import CDYahooKit
import UIKit

/// Displays one league's standings, fetched via
/// `CDYahooFantasyAPIClient.fetchLeagueStandings(leagueKey:)`, ranked by team.
final class StandingsViewController: UITableViewController {

    var client: CDYahooFantasyAPIClient!
    var leagueKey: String!

    private var teams: [CDYahooTeamStanding] = []

    private static let cellReuseIdentifier = "TeamStandingCell"

    override func viewDidLoad() {
        super.viewDidLoad()

        title = "Standings"

        Task { await loadStandings() }
    }

    private func loadStandings() async {
        do {
            let response = try await client.fetchLeagueStandings(leagueKey: leagueKey)
            teams = response.teams.sorted { ($0.rank ?? .max) < ($1.rank ?? .max) }
            tableView.reloadData()
        } catch {
            print("Failed to fetch standings: \(error)")
        }
    }

    override func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        teams.count
    }

    override func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        let cell = tableView.dequeueReusableCell(withIdentifier: Self.cellReuseIdentifier) ??
            UITableViewCell(style: .value1, reuseIdentifier: Self.cellReuseIdentifier)
        let team = teams[indexPath.row]

        let rankText = team.rank.map { "\($0). " } ?? ""
        cell.textLabel?.text = "\(rankText)\(team.name)"

        if let outcomeTotals = team.outcomeTotals {
            cell.detailTextLabel?.text = "\(outcomeTotals.wins)-\(outcomeTotals.losses)-\(outcomeTotals.ties)"
        }

        return cell
    }
}
