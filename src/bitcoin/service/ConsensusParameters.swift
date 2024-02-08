import Foundation

public struct ConsensusParameters {

    public let powLimit: Data
    public let powTargetTimespan: Int
    public let powTargetSpacing: Int
    public let powAllowMinDifficultyBlocks: Bool
    public let powNoRetargeting: Bool
    public var blockSubsidy = 50 * 100_000_000
    public let genesisBlockTime: Int
    public let genesisBlockNonce: Int
    public let genesisBlockTarget: Int

    var difficultyAdjustmentInterval: Int {
        powTargetTimespan / powTargetSpacing
    }
    // consensus.nSubsidyHalvingInterval = 150;
    // consensus.nRuleChangeActivationThreshold = 108; // 75% for testchains
    // consensus.nMinerConfirmationWindow = 144; // Faster than normal for regtest (144 instead of 2016)

    public static let mainnet = Self(
        powLimit: Data(hex: "00000000ffffffffffffffffffffffffffffffffffffffffffffffffffffffff")!,
        powTargetTimespan: 14 * 24 * 60 * 60, // Wrong
        powTargetSpacing: 10 * 60, // Wrong
        powAllowMinDifficultyBlocks: true, // Wrong
        powNoRetargeting: true, // Wrong
        genesisBlockTime: 1231006505,
        genesisBlockNonce: 2083236893,
        genesisBlockTarget: 0x1d00ffff
    )

    public static let regtest = Self(
        powLimit: Data(hex: "7fffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffff")!,
        powTargetTimespan: 14 * 24 * 60 * 60, // two weeks
        powTargetSpacing: 10 * 60,
        powAllowMinDifficultyBlocks: true,
        powNoRetargeting: true,
        genesisBlockTime: 1296688602,
        genesisBlockNonce: 2,
        genesisBlockTarget: 0x207fffff
    )
}
