import BitcoinBase
import Testing

@Suite("Block proof equivalent time")
struct EquivalentTimeTests {
    static let genesis = Target(compact: 0x1d00ffff)!     // work 0x100010001
    static let regtest = Target(compact: 0x207fffff)!     // work 2

    @Test func oneBlockAtTheTipsDifficultyIsOneSpacing() {
        let work = Self.genesis.work
        let time = Chainwork.blockProofEquivalentTime(
            to: work + work, from: work, tipTarget: Self.genesis, targetSpacing: 600)
        #expect(time == 600)
    }

    @Test func signFollowsDirection() {
        let a = Chainwork(low: 20), b = Chainwork(low: 10)
        #expect(Chainwork.blockProofEquivalentTime(to: a, from: b, tipTarget: Self.regtest, targetSpacing: 600) == 3000)
        #expect(Chainwork.blockProofEquivalentTime(to: b, from: a, tipTarget: Self.regtest, targetSpacing: 600) == -3000)
        #expect(Chainwork.blockProofEquivalentTime(to: a, from: a, tipTarget: Self.regtest, targetSpacing: 600) == 0)
    }

    @Test func roundsDown() {
        // 3 genesis blocks × 601 s, then just under one block
        let time = Chainwork.blockProofEquivalentTime(
            to: Chainwork(low: 0x1_0001_0001 * 3), from: .zero, tipTarget: Self.genesis, targetSpacing: 601)
        #expect(time == 1803)
        let below = Chainwork.blockProofEquivalentTime(
            to: Chainwork(low: 0x1_0001_0000), from: .zero, tipTarget: Self.genesis, targetSpacing: 1)
        #expect(below == 0)
    }

    @Test func multipliesAcrossTheWordBoundary() {
        // 2⁶⁴ × 600 ÷ 2 needs more than 64 bits; 2⁶² × 2 ÷ 2 does not
        let time = Chainwork.blockProofEquivalentTime(
            to: Chainwork(low: 1 << 64), from: .zero, tipTarget: Self.regtest, targetSpacing: 600)
        #expect(time == Int.max)                              // 300 × 2⁶⁴ doesn't fit
        let fits = Chainwork.blockProofEquivalentTime(
            to: Chainwork(low: 1 << 62), from: .zero, tipTarget: Self.regtest, targetSpacing: 2)
        #expect(fits == 1 << 62)
    }

    @Test func saturatesSymmetricallyLikeCore() {
        let huge = Chainwork(low: 0, high: 1)
        #expect(Chainwork.blockProofEquivalentTime(to: huge, from: .zero, tipTarget: Self.regtest, targetSpacing: 600) == Int.max)
        #expect(Chainwork.blockProofEquivalentTime(to: .zero, from: huge, tipTarget: Self.regtest, targetSpacing: 600) == -Int.max)
        let edge = Chainwork(low: UInt128(Int.max))
        #expect(Chainwork.blockProofEquivalentTime(to: edge, from: .zero, tipTarget: Self.regtest, targetSpacing: 2) == Int.max)
        #expect(Chainwork.blockProofEquivalentTime(to: edge + Chainwork(low: 2), from: .zero, tipTarget: Self.regtest, targetSpacing: 2) == Int.max)
    }

    @Test func productWrapsModulo2To256LikeCore() {
        // (2²⁵⁵) × 2 wraps to 0; Core's arith_uint256 does the same.
        let half = Chainwork(low: 0, high: 1 << 127)
        #expect(Chainwork.blockProofEquivalentTime(to: half, from: .zero, tipTarget: Self.regtest, targetSpacing: 2) == 0)
    }

    @Test func assumeValidTwoWeeks() {
        // swift-bitcoin's assumevalid check: 2016 genesis-difficulty blocks are exactly two weeks.
        let work = Self.genesis.work
        var tip = Chainwork.zero
        for _ in 0..<2016 { tip = tip + work }
        let time = Chainwork.blockProofEquivalentTime(to: tip, from: .zero, tipTarget: Self.genesis, targetSpacing: 600)
        #expect(time == 60 * 60 * 24 * 7 * 2)
    }
}
