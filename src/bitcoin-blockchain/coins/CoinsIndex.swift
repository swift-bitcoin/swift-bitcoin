import BitcoinBase

protocol CoinsIndex: Sendable {
    mutating func add(_ coin: UnspentOut, for outpoint: TxOutpoint) async
    func get(_ outpoint: TxOutpoint) async -> UnspentOut?
    mutating func remove(_ outpoint: TxOutpoint) async throws
}
