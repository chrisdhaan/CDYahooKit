//
//  CDYahooLeagueTransactionsResponse.swift
//  CDYahooKit
//

/// A player as they appear inside one transaction, with the move that was made.
public struct CDYahooTransactionPlayer: CDYahooXMLDecodable, Sendable, Equatable, Codable {
    public let playerKey: String
    public let fullName: String
    public let transactionType: String?
    public let destinationTeamKey: String?

    public init(playerKey: String, fullName: String, transactionType: String?, destinationTeamKey: String?) {
        self.playerKey = playerKey
        self.fullName = fullName
        self.transactionType = transactionType
        self.destinationTeamKey = destinationTeamKey
    }

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
public struct CDYahooTransaction: CDYahooXMLDecodable, Sendable, Equatable, Codable {
    public let transactionKey: String
    public let transactionId: String
    public let type: String
    public let status: String
    public let players: [CDYahooTransactionPlayer]

    public init(transactionKey: String, transactionId: String, type: String, status: String, players: [CDYahooTransactionPlayer]) {
        self.transactionKey = transactionKey
        self.transactionId = transactionId
        self.type = type
        self.status = status
        self.players = players
    }

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
public struct CDYahooLeagueTransactionsResponse: CDYahooXMLDecodable, Sendable, Equatable, Codable {
    public let leagueKey: String
    public let transactions: [CDYahooTransaction]

    public init(leagueKey: String, transactions: [CDYahooTransaction]) {
        self.leagueKey = leagueKey
        self.transactions = transactions
    }

    init(node: CDYahooXMLNode) throws {
        guard let leagueNode = node.child("league"), let leagueKey = leagueNode.text("league_key") else {
            throw CDYahooXMLDecodingError.missingField("league")
        }
        self.leagueKey = leagueKey
        let transactionNodes = leagueNode.child("transactions")?.children("transaction") ?? []
        self.transactions = try transactionNodes.map(CDYahooTransaction.init(node:))
    }
}
