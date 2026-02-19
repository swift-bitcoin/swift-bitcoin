import Foundation
import BitcoinCrypto
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
        chain: String = "mainnet",
        magicBytes: Int = 0xd9b4bef9,
        powLimit: Data = Data([0x00, 0x00, 0x00, 0x00, 0xff, 0xff, 0xff, 0xff, 0xff, 0xff, 0xff, 0xff, 0xff, 0xff, 0xff, 0xff, 0xff, 0xff, 0xff, 0xff, 0xff, 0xff, 0xff, 0xff, 0xff, 0xff, 0xff, 0xff, 0xff, 0xff, 0xff, 0xff]),
        powTargetTimespan: Int = 14 * 24 * 60 * 60, // two weeks
        powTargetSpacing: Int = 10 * 60,
        powAllowMinDifficultyBlocks: Bool = false,
        powNoRetargeting: Bool = false,
        preventBlockStorms: Bool = false,
        blockSubsidy: Amount = 5_000_000_000,
        genesisMessage: String = "The Times 03/Jan/2009 Chancellor on brink of second bailout for banks",
        genesisScript: Script = [.pushBytes(PublicKey.satoshi.uncompressedData!), .checkSig],
        genesisReward: Amount = 5_000_000_000,
        genesisBlockTime: Int = 1231006505,
        genesisBlockNonce: Int = 2083236893,
        genesisBlockTarget: Int = 0x1d00ffff,
        assumeValid: [UInt8]? = [0x77, 0x6d, 0xed, 0xa3, 0xad, 0x42, 0x97, 0xde, 0x9e, 0xf8, 0x11, 0x08, 0x79, 0xd2, 0x66, 0x2e, 0xe8, 0x20, 0x11, 0xdd, 0x58, 0xb6, 0x01, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00], // 00000000000000000001b658dd1120e82e66d2790811f89ede9742ada3ed6d77; Height 886157
        minChainwork: [UInt8] = /*.init(repeating: 0, count: 32), */ [0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x88, 0xe1, 0x86, 0xb7, 0x0e, 0x08, 0x62, 0xc1, 0x93, 0xec, 0x44, 0xd6],
        /// Data from RPC: getchaintxstats 4096 000000000000000000011c5890365bdbe5d25b97ce0057589acaef4f1a57263f
        chainData: ChainData = .init(time: 1723649144, txCount: 1059312821, txRate: 6.721086701157182),
        coinbaseMaturity: Int = Self.defaultCoinbaseMaturity,
        subsidyHalvingInterval: Int = 210_000,
        heightInCoinbaseHeight: Int = 227931,
        cltvHeight: Int = 388381,
        strictDERSignatureHeight: Int = 363725,
        csvHeight: Int = 419328,
        segwitHeight: Int = 481824
    ) {
        precondition(minChainwork.count == 32)
        self.chain = chain
        self.magicBytes = magicBytes
        self.powLimit = powLimit
        self.powTargetTimespan = powTargetTimespan
        self.powTargetSpacing = powTargetSpacing
        self.powAllowMinDifficultyBlocks = powAllowMinDifficultyBlocks
        self.powNoRetargeting = powNoRetargeting
        self.preventBlockStorms = preventBlockStorms
        self.blockSubsidy = blockSubsidy
        self.genesisMessage = genesisMessage
        self.genesisScript = genesisScript
        self.genesisReward = genesisReward
        self.genesisBlockTime = genesisBlockTime
        self.genesisBlockNonce = genesisBlockNonce
        self.genesisBlockTarget = genesisBlockTarget
        self.assumeValid = if let assumeValid { .init(assumeValid) } else { nil }
        self.minChainwork = minChainwork
        self.chainData = chainData
        self.subsidyHalvingInterval = subsidyHalvingInterval
        self.coinbaseMaturity = coinbaseMaturity
        self.heightInCoinbaseHeight = heightInCoinbaseHeight
        self.cltvHeight = cltvHeight
        self.strictDERSignatureHeight = strictDERSignatureHeight
        self.csvHeight = csvHeight
        self.segwitHeight = segwitHeight
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

    /// BIP94 rule 2 and 3. Testnet 4's "Block Storm" fix and "Time Warp Attack" mitigation.
    ///
    /// This is a new rule to address block storms caused by the testnet 20-minute exception.
    ///
    public let preventBlockStorms: Bool

    /// The initial block subsidy which defaults to 5 billion satoshis or 50 bitcoins.
    public var blockSubsidy = Amount(5_000_000_000)

    public let genesisMessage: String
    public let genesisScript: Script
    public let genesisReward: Amount
    public let genesisBlockTime: Int
    public let genesisBlockNonce: Int
    public let genesisBlockTarget: Int

    public let assumeValid: Block.ID? // TODO: Change to UInt256 or InlineArray<UInt8, 256>

    /// Big endian, 32 bytes (256 bit) number.
    public var minChainwork: [UInt8] // TODO: Change to UInt256 or InlineArray<UInt8, 256>
    let chainData: ChainData

    /// The number of blocks needed to be mined until a coinbase output may be spent. Defaults to 100.
    public let coinbaseMaturity: Int

    public let subsidyHalvingInterval: Int
    // consensus.nRuleChangeActivationThreshold = 108; // 75% for testchains
    // consensus.nMinerConfirmationWindow = 144; // Faster than normal for regtest (144 instead of 2016)

    /// BIP34 Height in Coinbase
    public let heightInCoinbaseHeight: Int

    /// BIP65 `OP_CHECKLOCKTIMEVERIFY`
    public let cltvHeight: Int

    /// BIP66 Strict DER signatures
    public let strictDERSignatureHeight: Int

    /// BIP68 Relative lock-time, BIP112 `CHECKSEQUENCEVERIFY`, BIP113 Median time-past
    public let csvHeight: Int

    /// BIP141 Segregated Witness, BIP143, BIP147 `NULLDUMMY`
    public let segwitHeight: Int

    public var difficultyAdjustmentInterval: Int {
        powTargetTimespan / powTargetSpacing
    }

    public var genesisTxParams: Transaction.GenesisParams {
        .init(
            timestampMessage: genesisMessage,
            reward: genesisReward,
            outputScript: genesisScript
        )
    }

    public static let mainnet = Self()

    /// Testnet (v4)
    /// BIP94
    public static let testnet = Self(
        chain: "testnet4",
        magicBytes: 0x283f161c,
        powAllowMinDifficultyBlocks: true,
        preventBlockStorms: true,
        genesisMessage: "03/May/2024 000000000000000000001ebd58c244970b3aa9d783bb001011fbe8ea8e98e00e",
        genesisScript: [Script.Operation.pushBytes(Data([0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00])), .checkSig],
        genesisBlockTime: 1714777860,
        genesisBlockNonce: 393743547,
        genesisBlockTarget: 0x1d00ffff,

        // Always revert to nil so 1st block testnet test does not crash
        assumeValid: nil, // [0x9b, 0x9d, 0x83, 0xac, 0x93, 0x0d, 0x66, 0x53, 0x4f, 0x89, 0x24, 0x75, 0x37, 0x76, 0xea, 0xb5, 0x84, 0xdb, 0xb0, 0xa3, 0x7f, 0x8e, 0xa5, 0x80, 0x01, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00],
        // 91000 000000000000000180a58e7fa3b0db84b5ea76377524894f53660d93ac839d9b
        // Use `xxd -revert -plain <<< '000000000000000180a58e7fa3b0db84b5ea76377524894f53660d93ac839d9b' | LC_ALL=C rev | tr -d '\n' | xxd -plain` to reverse.
        //
        // [0xf3, 0x89, 0x9a, 0x17, 0x43, 0xfa, 0xa9, 0x0a, 0xb4, 0x5c, 0x67, 0x25, 0xce, 0xff, 0xbc, 0xa6, 0x71, 0xb2, 0xd6, 0xf7, 0xf6, 0xbd, 0x8d, 0xf0, 0xd4, 0x3e, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00],
        // 0000000000003ed4f08dbdf6f7d6b271a6bcffce25675cb40aa9fa43179a89f3; height 72600

        minChainwork: [0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x03, 0x4a, 0x46, 0x90, 0xfe, 0x59, 0x2d, 0xc4, 0x9c, 0x7c], // 00000000000000000000000000000000000000000000034a4690fe592dc49c7c
        /// Data from RPC: getchaintxstats 4096 000000000000000180a58e7fa3b0db84b5ea76377524894f53660d93ac839d9b
        chainData: .init(time: 1752470331, txCount: 11414302, txRate: 0.2842619757327476),
        heightInCoinbaseHeight: 1,
        cltvHeight: 1,
        strictDERSignatureHeight: 1,
        csvHeight: 1,
        segwitHeight: 1
    )

    public static let regtest = Self(
        chain: "regtest",
        magicBytes: 0xdab5bffa,
        powLimit: Data([0x7f, 0xff, 0xff, 0xff, 0xff, 0xff, 0xff, 0xff, 0xff, 0xff, 0xff, 0xff, 0xff, 0xff, 0xff, 0xff, 0xff, 0xff, 0xff, 0xff, 0xff, 0xff, 0xff, 0xff, 0xff, 0xff, 0xff, 0xff, 0xff, 0xff, 0xff, 0xff]),
        powTargetTimespan: 24 * 60 * 60, // one day
        powAllowMinDifficultyBlocks: true,
        powNoRetargeting: true,
        preventBlockStorms: false, // In Bitcoin Core there is a configuration option / command line parameter to set this to true on regtest (will mitigate timewarp attack).
        genesisBlockTime: 1296688602,
        genesisBlockNonce: 2,
        genesisBlockTarget: 0x207fffff,
        assumeValid: nil,
        minChainwork: .init(repeating: 0, count: 32),
        chainData: .init(),
        subsidyHalvingInterval: 150,
        heightInCoinbaseHeight: 1,
        cltvHeight: 1,
        strictDERSignatureHeight: 1,
        csvHeight: 1,
        segwitHeight: 0
    )

    package static let swiftTesting = Self( // Similar to regtest
        chain: "swift-testing",
        magicBytes: 0xdab5bffa,
        powLimit: Data([0x7f, 0xff, 0xff, 0xff, 0xff, 0xff, 0xff, 0xff, 0xff, 0xff, 0xff, 0xff, 0xff, 0xff, 0xff, 0xff, 0xff, 0xff, 0xff, 0xff, 0xff, 0xff, 0xff, 0xff, 0xff, 0xff, 0xff, 0xff, 0xff, 0xff, 0xff, 0xff]),
        powTargetTimespan: 24 * 60 * 60, // one day
        powAllowMinDifficultyBlocks: true,
        powNoRetargeting: true,
        genesisBlockTime: 1296688602,
        genesisBlockNonce: 2,
        genesisBlockTarget: 0x207fffff,
        assumeValid: nil,
        minChainwork: .init(repeating: 0, count: 32),
        chainData: .init(),
        coinbaseMaturity: 1,
        subsidyHalvingInterval: 150,
        heightInCoinbaseHeight: 1,
        cltvHeight: 1,
        strictDERSignatureHeight: 1,
        csvHeight: 1,
        segwitHeight: 0
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
    package static let maxTimewarp = TimeInterval(600)
}
