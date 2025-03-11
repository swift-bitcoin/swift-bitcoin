import Collections
import Logging
import BitcoinBase

private let logger = Logger(label: "swift-bitcoin.coins-index")

/// An index plus in-memory storage for coins.
struct InMemoryCoinsIndex: CoinsIndex {

    private var coins = OrderedDictionary<TxOutpoint, UnspentOut>()

    mutating func add(_ coin: UnspentOut, for outpoint: TxOutpoint) async {
        coins[outpoint] = coin
    }

    func get(_ outpoint: TxOutpoint) async -> UnspentOut? { // TODO: Probably should throw
        coins[outpoint]
    }

    mutating func remove(_ outpoint: TxOutpoint) async {
        coins[outpoint] = .none
    }
}
