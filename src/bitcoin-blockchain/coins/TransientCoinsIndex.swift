import Collections
import Logging
import BitcoinBase

/// An index plus in-memory storage for coins.
struct TransientCoinsIndex: CoinsIndex {

    private var coins = OrderedDictionary<Outpoint, UnspentOutput>()

    mutating func add(_ coin: UnspentOutput, for outpoint: Outpoint) async {
        coins[outpoint] = coin
    }

    func get(_ outpoint: Outpoint) async -> UnspentOutput? { // TODO: Probably should throw
        coins[outpoint]
    }

    mutating func remove(_ outpoint: Outpoint) async {
        coins[outpoint] = nil
    }
}
