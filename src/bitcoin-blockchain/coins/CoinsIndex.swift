import BitcoinBase

/// Coins index, also known as chain state.
///
/// A list of unspent outputs (coins) indexed by outpoint (transaction ID plus offset).
protocol CoinsIndex: Sendable {

    var all: [Outpoint : UnspentOutput] { get async }
    func get(_ outpoint: Outpoint) async throws(CoinsError) -> UnspentOutput?

    /// Removes spent coins and adds new unspent ones.
    /// - Parameters:
    ///   - remove: A list of outpoints to remove.
    ///   - add: A map of outpoints to coins.
    /// - Returns: A list of removed coins with "holes" which are the coins that could not be removed because they were not found.
    @discardableResult mutating func update(remove: [Outpoint], add: [Outpoint : UnspentOutput]) async throws(CoinsError) -> [UnspentOutput?]

    mutating func add(_ coin: UnspentOutput, for outpoint: Outpoint) async
    mutating func remove(_ outpoint: Outpoint) async throws
}

enum CoinsError: Error {

    /// When trying to remove spent coins, no unspent output was found for at least on of the provided outpoints.
    case spentCoinNotFound

    case corruptedCoinData

    case databaseError(Error)
}
