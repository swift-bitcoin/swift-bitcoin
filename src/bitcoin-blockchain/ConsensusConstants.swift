import BitcoinBase

// MARK: - Flags from `consensus.h` in Bitcoin Core.
private enum ConsensusConstants {

    // MARK: - Transaction


    // MARK: - Block

    /// See ``BitcoinBase/Block/maxWeight``.
    static let maxBlockWeight = 4_000_000

    /// See ``BitcoinBase/Block/maxSerializedSize``.
    static let maxBlockSerializedSized = 4_000_000

    /// See ``BitcoinBase/Block/coinbaseMaturity``.
    static let coinbaseMaturity = 100

    /// The maximum allowed number of signature check operations in a block (network rule)
    ///
    /// Unused as of May 18, 2026
    static let maxBlockSigopsCost = 80_000

    /// `MIN_TRANSACTION_WEIGHT` in Bitcoin Core.
    ///
    /// Unused as of May 18, 2026
    static let minTransactionWeight = Transaction.witnessScaleFactor * 60 // 60 is the lower bound for the size of a valid serialized CTransaction

    /// `MIN_SERIALIZABLE_TRANSACTION_WEIGHT` in Bitcoin Core.
    ///
    /// Unused as of May 18, 2026
    static let minSerializableTransactionWeight = Transaction.witnessScaleFactor * 10 // 10 is the lower bound for the size of a serialized CTransaction
}

public extension Block {

    /// The maximum allowed weight for a block, see BIP141 (network rule)
    static let maxWeight = ConsensusConstants.maxBlockWeight

    /// The maximum allowed size for a serialized block, in bytes (only for buffer size limits)
    ///
    /// Used for storage only (not consensus) as of May 18, 2026
    static let maxSerializedSize = ConsensusConstants.maxBlockSerializedSized

    /// Coinbase transaction outputs can only be spent after this number of new blocks (network rule)
    static let coinbaseMaturity = ConsensusConstants.coinbaseMaturity
}
