import Foundation
import BitcoinBase

public struct ConsensusParams: Sendable {

    public struct ChainData: Sendable {

        public init(time: Int = 0, txCount: Int = 0, txRate: Double = 0) {
            self.time = time
            self.txCount = txCount
            self.txRate = txRate
        }

        public let time: Int
        public let txCount: Int
        public let txRate: Double
    }

    public init(
        chain: String,
        magicBytes: Int,
        powLimit: Data,
        powTargetTimespan: Int,
        powTargetSpacing: Int,
        powAllowMinDifficultyBlocks: Bool,
        powNoRetargeting: Bool,
        blockSubsidy: Int = 50 * 100_000_000,
        genesisBlockTime: Int,
        genesisBlockNonce: Int,
        genesisBlockTarget: Int,
        minChainwork: [UInt8] = .init(repeating: 0, count: 32),
        chainData: ChainData = .init(),
        coinbaseMaturity: Int = Self.defaultCoinbaseMaturity
    ) {
        precondition(minChainwork.count == 32)
        self.chain = chain
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
        self.minChainwork = minChainwork
        self.chainData = chainData
    }

    /// The chain identifier: mainnet, testnet, signet, regtest
    public let chain: String

    /// Used for block files.
    public let magicBytes: Int

    public let powLimit: Data
    public let powTargetTimespan: Int
    public let powTargetSpacing: Int
    public let powAllowMinDifficultyBlocks: Bool
    public let powNoRetargeting: Bool

    /// The initial block subsidy which defaults to 5 billion satoshis or 50 bitcoins.
    public var blockSubsidy = SatoshiAmount(5_000_000_000)

    public let genesisBlockTime: Int
    public let genesisBlockNonce: Int
    public let genesisBlockTarget: Int

    /// Big endian, 32 bytes (256 bit) number.
    let minChainwork: [UInt8]
    let chainData: ChainData

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
        chain: "mainnet",
        magicBytes: 0xd9b4bef9,
        powLimit: Data([0x00, 0x00, 0x00, 0x00, 0xff, 0xff, 0xff, 0xff, 0xff, 0xff, 0xff, 0xff, 0xff, 0xff, 0xff, 0xff, 0xff, 0xff, 0xff, 0xff, 0xff, 0xff, 0xff, 0xff, 0xff, 0xff, 0xff, 0xff, 0xff, 0xff, 0xff, 0xff]),
        powTargetTimespan: 14 * 24 * 60 * 60, // Wrong
        powTargetSpacing: 10 * 60, // Wrong
        powAllowMinDifficultyBlocks: true, // Wrong
        powNoRetargeting: true, // Wrong
        genesisBlockTime: 1231006505,
        genesisBlockNonce: 2083236893,
        genesisBlockTarget: 0x1d00ffff,

        minChainwork: [0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x88, 0xe1, 0x86, 0xb7, 0x0e, 0x08, 0x62, 0xc1, 0x93, 0xec, 0x44, 0xd6],

        /// Data from RPC: getchaintxstats 4096 000000000000000000011c5890365bdbe5d25b97ce0057589acaef4f1a57263f
        chainData: .init(time: 1723649144, txCount: 1059312821, txRate: 6.721086701157182)
    )

    /// Testnet v3
    public static let testnet  = Self(
        chain: "testnet",
        magicBytes: 0xdab5bffa,
        powLimit: Data([0x7f, 0xff, 0xff, 0xff, 0xff, 0xff, 0xff, 0xff, 0xff, 0xff, 0xff, 0xff, 0xff, 0xff, 0xff, 0xff, 0xff, 0xff, 0xff, 0xff, 0xff, 0xff, 0xff, 0xff, 0xff, 0xff, 0xff, 0xff, 0xff, 0xff, 0xff, 0xff]),
        powTargetTimespan: 14 * 24 * 60 * 60, // two weeks
        powTargetSpacing: 10 * 60,
        powAllowMinDifficultyBlocks: true,
        powNoRetargeting: true,
        genesisBlockTime: 1296688602,
        genesisBlockNonce: 2,
        genesisBlockTarget: 0x207fffff,

        minChainwork: [0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x0f, 0x20, 0x96, 0x95, 0x16, 0x6b, 0xe8, 0xb6, 0x1f, 0xa9],

        /// Data from RPC: getchaintxstats 4096 000000000000000465b1a66c9f386308e8c75acef9201f3f577811da09fc90ad
        chainData: .init(time: 1723613341, txCount: 187917082, txRate: 3.265051477698455)
    )

    /// Testnet v4
    public static let testnet4 = Self(
        chain: "testnet4",
        magicBytes: 0xdab5bffa,
        powLimit: Data([0x7f, 0xff, 0xff, 0xff, 0xff, 0xff, 0xff, 0xff, 0xff, 0xff, 0xff, 0xff, 0xff, 0xff, 0xff, 0xff, 0xff, 0xff, 0xff, 0xff, 0xff, 0xff, 0xff, 0xff, 0xff, 0xff, 0xff, 0xff, 0xff, 0xff, 0xff, 0xff]),
        powTargetTimespan: 14 * 24 * 60 * 60, // two weeks
        powTargetSpacing: 10 * 60,
        powAllowMinDifficultyBlocks: true,
        powNoRetargeting: true,
        genesisBlockTime: 1296688602,
        genesisBlockNonce: 2,
        genesisBlockTarget: 0x207fffff,

        minChainwork: [0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x5f, 0xaa, 0x15, 0xd0, 0x2e, 0x62, 0x02, 0xf3, 0xba],

        /// Data from RPC: getchaintxstats 4096 000000005be348057db991fa5d89fe7c4695b667cfb311391a8db374b6f681fd
        chainData: .init(time: 1723651702, txCount: 757229, txRate: 0.01570402633472492)
    )

    public static let regtest = Self(
        chain: "regtest",
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
        chain: "swift-testing",
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
    public static let maxBlockSerializedSized = 4_000_000

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
