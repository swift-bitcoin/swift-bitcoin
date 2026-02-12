import Collections
import Logging
import BitcoinBase

/// An index plus in-memory storage for coins.
struct TransientCoinsIndex: CoinsIndex {

    private var coins = [Outpoint: UnspentOutput]()

    var all: [Outpoint : UnspentOutput] { coins }

    func get(_ outpoint: Outpoint) -> UnspentOutput? {
        coins[outpoint]
    }

    mutating func update(remove outpointsToRemove: [Outpoint], add coinsToAdd: [Outpoint : UnspentOutput]) throws(CoinsError) -> [UnspentOutput?] {
        var removedCoins = [UnspentOutput?]()
        for outpoint in outpointsToRemove {
            guard let coin = coins[outpoint] else {
                removedCoins.append(nil)
                continue // Some coins may be spends from within the block
            }
            removedCoins.append(coin)
            coins[outpoint] = nil
        }
        for (outpoint, coin) in coinsToAdd {
            coins[outpoint] = coin
        }
        return removedCoins
    }

    mutating func add(_ coin: UnspentOutput, for outpoint: Outpoint) {
        coins[outpoint] = coin
    }

    mutating func remove(_ outpoint: Outpoint) {
        coins[outpoint] = nil
    }

    mutating func clear() {
        coins = .init()
    }
}
