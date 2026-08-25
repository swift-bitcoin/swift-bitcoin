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
        magicBytes: Int = 0xd9b4bef9, // Sent/stored as little endian `[0xf9, 0xbe, 0xb4, 0xd9]`
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
        coinbaseMaturity: Int = Block.coinbaseMaturity,
        subsidyHalvingInterval: Int = 210_000,
        heightInCoinbaseHeight: Int = 227931,
        cltvHeight: Int = 388381,
        strictDERSignatureHeight: Int = 363725,
        csvHeight: Int = 419328,
        segwitHeight: Int = 481824,
        signetChallenge: Script? = nil
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
        self.minChainwork = try! DifficultyTarget(Data(minChainwork.reversed()))
        self.chainData = chainData
        self.subsidyHalvingInterval = subsidyHalvingInterval
        self.coinbaseMaturity = coinbaseMaturity
        self.heightInCoinbaseHeight = heightInCoinbaseHeight
        self.cltvHeight = cltvHeight
        self.strictDERSignatureHeight = strictDERSignatureHeight
        self.csvHeight = csvHeight
        self.segwitHeight = segwitHeight
        self.signetChallenge = signetChallenge
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
    public var minChainwork: DifficultyTarget // [UInt8] // TODO: Change to UInt256 or InlineArray<UInt8, 256>
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

    public var signetChallenge: Script?

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
        magicBytes: 0x283f161c, // Sent/stored as little endian `[0x1c, 0x16, 0x3f, 0x28]`
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
        magicBytes: 0xdab5bffa, // Sent/stored as little endian `[0xfa, 0xbf, 0xb5, 0xda]`
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

    public static func signet(options: SignetOptions = .init()) -> Self {
        let resolvedChallenge: Script
        let assumeValid: [UInt8]?
        let minChainwork: [UInt8]
        let chainData: ChainData

        if let challenge = options.challenge {
            resolvedChallenge = challenge
            assumeValid = nil
            minChainwork = .init(repeating: 0, count: 32)
            // m_assumed_blockchain_size = 0;
            // m_assumed_chain_state_size = 0;
            chainData = .init()
        } else {
            // bin = "512103ad5e0edad18cb1f0fc0d28a3d4f1f3e445640337489abb10404f2d1e086be430210359ef5021964fe22d6f8e05b2463c9540ce96883fe3b278760f048f5189f2e6c452ae"_hex_v_u8;
            resolvedChallenge = try! Script([0x51, 0x21, 0x03, 0xad, 0x5e, 0x0e, 0xda, 0xd1, 0x8c, 0xb1, 0xf0, 0xfc, 0x0d, 0x28, 0xa3, 0xd4, 0xf1, 0xf3, 0xe4, 0x45, 0x64, 0x03, 0x37, 0x48, 0x9a, 0xbb, 0x10, 0x40, 0x4f, 0x2d, 0x1e, 0x08, 0x6b, 0xe4, 0x30, 0x21, 0x03, 0x59, 0xef, 0x50, 0x21, 0x96, 0x4f, 0xe2, 0x2d, 0x6f, 0x8e, 0x05, 0xb2, 0x46, 0x3c, 0x95, 0x40, 0xce, 0x96, 0x88, 0x3f, 0xe3, 0xb2, 0x78, 0x76, 0x0f, 0x04, 0x8f, 0x51, 0x89, 0xf2, 0xe6, 0xc4, 0x52, 0xae])

            // TODO: - Deal with seeds for all default networks
            // vFixedSeeds = std::vector<uint8_t>(std::begin(chainparams_seed_signet), std::end(chainparams_seed_signet));
            // vSeeds.emplace_back("seed.signet.bitcoin.sprovoost.nl.");
            // vSeeds.emplace_back("seed.signet.achownodes.xyz."); // Ava Chow, only supports x1, x5, x9, x49, x809, x849, xd, x400, x404, x408, x448, xc08, xc48, x40c

            // consensus.defaultAssumeValid = uint256{"00000008414aab61092ef93f1aacc54cf9e9f16af29ddad493b908a01ff5c329"}; // 293175
            assumeValid = [0x29, 0xc3, 0xf5, 0x1f, 0xa0, 0x08, 0xb9, 0x93, 0xd4, 0xda, 0x9d, 0xf2, 0x6a, 0xf1, 0xe9, 0xf9, 0x4c, 0xc5, 0xac, 0x1a, 0x3f, 0xf9, 0x2e, 0x09, 0x61, 0xab, 0x4a, 0x41, 0x08, 0x00, 0x00, 0x00]

            // consensus.nMinimumChainWork = uint256{"00000000000000000000000000000000000000000000000000000b463ea0a4b8"};
            minChainwork = [0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x0b, 0x46, 0x3e, 0xa0, 0xa4, 0xb8]

            // TODO: - Figure out what to do with assume blockchain size and assumed chain state size for all networks
            // m_assumed_blockchain_size = 24;
            // m_assumed_chain_state_size = 4;

            // Data from RPC: getchaintxstats 4096 00000008414aab61092ef93f1aacc54cf9e9f16af29ddad493b908a01ff5c329
            chainData = .init(time: 1772055248, txCount: 28676833, txRate: 0.06736623436338929)

        }

        // Message start (magic bytes) is defined as the first 4 bytes of the sha256d (Hash256) of the block script.
        // Default signet magic bytes: [0x06, 0x03, 0xcf, 0x40] or as a big endian literal: `0x40cf030a`.
        // var hasher = Hash256()
        //hasher.update(data: VarInt(resolvedChallenge.count).data)
        //hasher.update(data: resolvedChallenge)
        let hash = Hash256.hash(data: resolvedChallenge.dataPrefixed)
        let magicBytes = [UInt8](hash.prefix(4))

        let magicBytesInt = Int(magicBytes[3]) << 24 |
                            Int(magicBytes[2]) << 16 |
                            Int(magicBytes[1]) << 8  |
                            Int(magicBytes[0])

        return .init(
            chain: "signet",
            magicBytes: magicBytesInt,
            // consensus.powLimit = uint256{"00000377ae000000000000000000000000000000000000000000000000000000"};
            powLimit: .init([0x00, 0x00, 0x03, 0x77, 0xae, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00]),
            powTargetTimespan: 14 * 24 * 60 * 60, // two weeks
            powTargetSpacing: 10 * 60,
            powAllowMinDifficultyBlocks: false,
            powNoRetargeting: false,

            // consensus.enforce_BIP94 = false;
            preventBlockStorms: false,

            //blockSubsidy: Amount,
            //genesisMessage: String,
            //genesisScript: Script,
            genesisReward: 5_000_000_000,
            genesisBlockTime: 1598918400,
            genesisBlockNonce: 52613770,
            genesisBlockTarget: 0x1e0377ae,
            assumeValid: assumeValid,
            minChainwork: minChainwork,
            chainData: chainData,
            //coinbaseMaturity: Int,
            subsidyHalvingInterval: 210_000,
            heightInCoinbaseHeight: 1,
            cltvHeight: 1,
            strictDERSignatureHeight: 1,
            csvHeight: 1,
            segwitHeight: 1,
            signetChallenge: resolvedChallenge
        )
    }

    package static let swiftTesting = Self( // Similar to regtest
        chain: "swift-testing",
        magicBytes: 0xdab5bffa, // Sent/stored as little endian `[0xfa, 0xbf, 0xb5, 0xda]`
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

    // TODO: Define testnet params with magicBytes 0x0709110b (big endian literas; sent/stored as little endian `[0x0b, 0x11, 0x09, 0x07]`)
}

public struct SignetOptions {
    public init(challenge: Script? = nil) {
        self.challenge = challenge
    }
    
    let challenge: Script?
}
