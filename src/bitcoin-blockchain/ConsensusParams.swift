import Foundation
import BitcoinBase

public struct ConsensusParams: Sendable {
    public init(magicBytes: Int, powLimit: Data, powTargetTimespan: Int, powTargetSpacing: Int, powAllowMinDifficultyBlocks: Bool, powNoRetargeting: Bool, blockSubsidy: Int = 50 * 100_000_000, genesisBlockTime: Int, genesisBlockNonce: Int, genesisBlockTarget: Int, coinbaseMaturity: Int = Self.defaultCoinbaseMaturity) {
        self.magicBytes = magicBytes
        self.powLimit = powLimit
        self.powTargetTimespan = powTargetTimespan
        self.powTargetSpacing = powTargetSpacing
        self.powAllowMinDifficultyBlocks = powAllowMinDifficultyBlocks
        self.powNoRetargeting = powNoRetargeting
        self.blockSubsidy = blockSubsidy
        self.genesisBlockTime = genesisBlockTime
        self.genesisBlockNonce = genesisBlockNonce
        self.genesisBlockTarget = genesisBlockTarget
        self.coinbaseMaturity = coinbaseMaturity
    }

    /// Used for block files.
    public let magicBytes: Int

    public let powLimit: Data
    public let powTargetTimespan: Int
    public let powTargetSpacing: Int
    public let powAllowMinDifficultyBlocks: Bool
    public let powNoRetargeting: Bool

    public let genesisBlockTime: Int
    public let genesisBlockNonce: Int
    public let genesisBlockTarget: Int

    /// The initial block subsidy which defaults to 5 billion satoshis or 50 bitcoins.
    public var blockSubsidy = SatoshiAmount(5_000_000_000)

    /// The number of blocks needed to be mined until a coinbase output may be spent. Defaults to 100.
    public let coinbaseMaturity: Int

    ///
    public let subsidyHalvingInterval = 150
    // consensus.nRuleChangeActivationThreshold = 108; // 75% for testchains
    // consensus.nMinerConfirmationWindow = 144; // Faster than normal for regtest (144 instead of 2016)

    public var difficultyAdjustmentInterval: Int {
        powTargetTimespan / powTargetSpacing
    }

    public static let mainnet = Self(
        magicBytes: 0xd9b4bef9,
        powLimit: Data([0x00, 0x00, 0x00, 0x00, 0xff, 0xff, 0xff, 0xff, 0xff, 0xff, 0xff, 0xff, 0xff, 0xff, 0xff, 0xff, 0xff, 0xff, 0xff, 0xff, 0xff, 0xff, 0xff, 0xff, 0xff, 0xff, 0xff, 0xff, 0xff, 0xff, 0xff, 0xff]),
        powTargetTimespan: 14 * 24 * 60 * 60, // Wrong
        powTargetSpacing: 10 * 60, // Wrong
        powAllowMinDifficultyBlocks: true, // Wrong
        powNoRetargeting: true, // Wrong
        genesisBlockTime: 1231006505,
        genesisBlockNonce: 2083236893,
        genesisBlockTarget: 0x1d00ffff
    )

    public static let regtest = Self(
        magicBytes: 0xdab5bffa,
        powLimit: Data([0x7f, 0xff, 0xff, 0xff, 0xff, 0xff, 0xff, 0xff, 0xff, 0xff, 0xff, 0xff, 0xff, 0xff, 0xff, 0xff, 0xff, 0xff, 0xff, 0xff, 0xff, 0xff, 0xff, 0xff, 0xff, 0xff, 0xff, 0xff, 0xff, 0xff, 0xff, 0xff]),
        powTargetTimespan: 14 * 24 * 60 * 60, // two weeks
        powTargetSpacing: 10 * 60,
        powAllowMinDifficultyBlocks: true,
        powNoRetargeting: true,
        genesisBlockTime: 1296688602,
        genesisBlockNonce: 2,
        genesisBlockTarget: 0x207fffff
    )

    package static let swiftTesting = Self( // Similar to regtest
        magicBytes: 0xdab5bffa,
        powLimit: Data([0x7f, 0xff, 0xff, 0xff, 0xff, 0xff, 0xff, 0xff, 0xff, 0xff, 0xff, 0xff, 0xff, 0xff, 0xff, 0xff, 0xff, 0xff, 0xff, 0xff, 0xff, 0xff, 0xff, 0xff, 0xff, 0xff, 0xff, 0xff, 0xff, 0xff, 0xff, 0xff]),
        powTargetTimespan: 14 * 24 * 60 * 60, // two weeks
        powTargetSpacing: 10 * 60,
        powAllowMinDifficultyBlocks: true,
        powNoRetargeting: true,
        genesisBlockTime: 1296688602,
        genesisBlockNonce: 2,
        genesisBlockTarget: 0x207fffff,
        coinbaseMaturity: 1
    )

    // TODO: Define testnet params with magicBytes 0x0709110b
    // TODO: Define signet params with magicBytes 0x40cf030a

    // MARK: - Flags from `consensus.h` in Bitcoin Core.

    /// The maximum allowed size for a serialized block, in bytes (only for buffer size limits)
    /// Unused as of Jan 8 2025
    private static let maxBlockSerializedSized = 4_000_000

    /// The maximum allowed weight for a block, see BIP141 (network rule)
    public static let maxBlockWeight = 4_000_000

    /// The maximum allowed number of signature check operations in a block (network rule)
    private static let maxBlockSigopsCost = 80_000

    /// Coinbase transaction outputs can only be spent after this number of new blocks (network rule)
    public static let defaultCoinbaseMaturity = 100

    private static let witnessScaleFactor = 4

    /// `MIN_TRANSACTION_WEIGHT` in Bitcoin Core.
    private static let minTransactionWeight = witnessScaleFactor * 60 // 60 is the lower bound for the size of a valid serialized CTransaction

    /// `MIN_SERIALIZABLE_TRANSACTION_WEIGHT` in Bitcoin Core.
    private static let minSerializableTransactionWeight = witnessScaleFactor * 10 // 10 is the lower bound for the size of a serialized CTransaction

    // MARK: - Flags for nSequence and nLockTime locks

    /// Interpret sequence numbers as relative lock-time constraints.
    private static let locktimeVerifySequence = 1 << 0

    /// Maximum number of seconds that the timestamp of the first block of a difficulty adjustment period is allowed to be earlier than the last block of the previous period (BIP94).
    private static let maxTimewarp = 600
}
