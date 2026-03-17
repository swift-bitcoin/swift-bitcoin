import Collections
import Logging
import BitcoinBase

/// An index plus in-memory storage for coins.
struct TransientCoinIndex: CoinIndex {

    private var _coins = [Outpoint: UnspentOutput]()

    var coins: [Outpoint : UnspentOutput] { _coins }

    func get(_ outpoint: Outpoint) -> UnspentOutput? {
        _coins[outpoint]
    }

    mutating func update(remove outpointsToRemove: [Outpoint], add coinsToAdd: [Outpoint : UnspentOutput]) throws(CoinsError) -> [UnspentOutput?] {
        var removedCoins = [UnspentOutput?]()
        for outpoint in outpointsToRemove {
            guard let coin = _coins[outpoint] else {
                removedCoins.append(nil)
                continue // Some coins may be spends from within the block
            }
            removedCoins.append(coin)
            _coins[outpoint] = nil
        }
        for (outpoint, coin) in coinsToAdd {
            _coins[outpoint] = coin
        }
        return removedCoins
    }

    mutating func clear() {
        _coins = .init()
    }
}
