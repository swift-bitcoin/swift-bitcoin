import Foundation

public struct ConsensusParameters {

    public let powLimit: Data
    public let powTargetTimespan: Int
    public let powTargetSpacing: Int
    public let powAllowMinDifficultyBlocks: Bool
    public let powNoRetargeting: Bool

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
        powNoRetargeting: true // Wrong
    )

    public static let regtest = Self(
        powLimit: Data(hex: "7fffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffff")!,
        powTargetTimespan: 14 * 24 * 60 * 60, // two weeks
        powTargetSpacing: 10 * 60,
        powAllowMinDifficultyBlocks: true,
        powNoRetargeting: true
    )
}
