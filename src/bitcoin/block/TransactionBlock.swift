import Foundation
import BitcoinCrypto

/// A block of transactions.
public struct TransactionBlock: Equatable, Sendable {

    // MARK: - Initializers

    public init(header: BlockHeader, transactions: [BitcoinTransaction] = []) {
        self.header = header
        self.transactions = transactions
    }

    // MARK: - Instance Properties

    public let header: BlockHeader
    public let transactions: [BitcoinTransaction]

    // MARK: - Computed Properties

    public var hash: Data {
        hash256(header.data)
    }

    public var identifier: Data {
        Data(hash.reversed())
    }

    // MARK: - Instance Methods

    // MARK: - Type Properties

    // MARK: - Type Methods

    static func makeGenesisBlock(consensusParams: ConsensusParams) -> Self {
        let genesisTx = BitcoinTransaction.makeGenesisTransaction(consensusParams: consensusParams)
        let genesisBlock = TransactionBlock(
            header: .init(
                version: 1,
                previous: Data(count: 32),
                merkleRoot: genesisTx.identifier,
                time: Date(timeIntervalSince1970: TimeInterval(consensusParams.genesisBlockTime)),
                target: consensusParams.genesisBlockTarget,
                nonce: consensusParams.genesisBlockNonce
            ),
            transactions: [genesisTx])
        return genesisBlock
    }
}
