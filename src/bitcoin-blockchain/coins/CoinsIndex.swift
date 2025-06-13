import BitcoinBase

protocol CoinsIndex: Sendable {
    mutating func add(_ coin: UnspentOutput, for outpoint: Outpoint) async
    func get(_ outpoint: Outpoint) async -> UnspentOutput?
    mutating func remove(_ outpoint: Outpoint) async throws
}
