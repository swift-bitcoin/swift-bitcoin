import BitcoinBase
import Foundation

// MARK: - Flags from `consensus.h` in Bitcoin Core.
enum ConsensusConstants {

    // MARK: - Transaction

    /// See ``BitcoinBase/Transaction/witnessScaleFactor``.
    ///
    /// `WITNESS_SCALE_FACTOR`
    static let witnessScaleFactor = 4

    // MARK: - Block

    /// See ``BitcoinBase/Block/maxWeight``.
    ///
    /// `MAX_BLOCK_WEIGHT`
    static let maxBlockWeight = 4_000_000

    /// See ``BitcoinBase/Block/maxSerializedSize``.
    ///
    /// `MAX_BLOCK_SERIALIZED_SIZE`
    static let maxBlockSerializedSized = 4_000_000

    /// See ``BitcoinBase/Block/maxSigopsCost``.
    ///
    /// `MAX_BLOCK_SIGOPS_COST`
    static let maxBlockSigopsCost = 80_000

    /// See ``BitcoinBase/Block/coinbaseMaturity``.
    ///
    /// `COINBASE_MATURITY`
    static let coinbaseMaturity = 100

    /// `MIN_TRANSACTION_WEIGHT` in Bitcoin Core.
    ///
    /// Unused as of May 18, 2026
    static let minTransactionWeight = Transaction.witnessScaleFactor * 60 // 60 is the lower bound for the size of a valid serialized CTransaction

    /// `MIN_SERIALIZABLE_TRANSACTION_WEIGHT` in Bitcoin Core.
    ///
    /// Unused as of May 18, 2026
    static let minSerializableTransactionWeight = Transaction.witnessScaleFactor * 10 // 10 is the lower bound for the size of a serialized CTransaction

    /// See ``BitcoinBase/Block/maxTimewarp``.
    ///
    /// `MAX_TIMEWARP`
    static let maxTimewarp = TimeInterval(600)

    /// See ``BitcoinBase/Transaction/Input/locktimeVerifySequence``.
    ///
    /// `LOCKTIME_VERIFY_SEQUENCE`
    static let locktimeVerifySequence = true // 1 << 0
}

/// Consensus.
public extension Transaction {

    /// Witness scale factor.
    static let witnessScaleFactor = ConsensusConstants.witnessScaleFactor
}

/// Consensus.
public extension Transaction.Input {

    /// Interpret sequence numbers as relative lock-time constraints.
    static let locktimeVerifySequence = ConsensusConstants.locktimeVerifySequence
}

/// Consensus.
public extension Block {

    /// The maximum allowed weight for a block, see BIP141 (network rule)
    static let maxWeight = ConsensusConstants.maxBlockWeight

    /// The maximum allowed size for a serialized block, in bytes (only for buffer size limits)
    ///
    /// Used for storage only (not consensus) as of May 18, 2026
    static let maxSerializedSize = ConsensusConstants.maxBlockSerializedSized

    /// The maximum allowed number of signature check operations in a block (network rule)
    static let maxSigopsCost = ConsensusConstants.maxBlockSigopsCost

    /// Coinbase transaction outputs can only be spent after this number of new blocks (network rule)
    static let coinbaseMaturity = ConsensusConstants.coinbaseMaturity

    /// Maximum number of seconds that the timestamp of the first block of a difficulty adjustment period is allowed to be earlier than the last block of the previous period (BIP94).
    static let maxTimewarp = ConsensusConstants.maxTimewarp
}
