import BitcoinBase
import Testing

private func block(hex: String) -> BlockHash {
    BlockHash(displayHex: String(repeating: "0", count: 64 - hex.count) + hex)!
}

private func target(hex: String) -> Target {
    Target(hex: hex)!
}

@Suite("BlockHash.meetsTarget")
struct MeetsTargetTests {
    /// `hash <= target`: equal and one less pass, one more fails.
    @Test(arguments: ["1", "ff", "100", "ffffffffffffffff", "1" + String(repeating: "0", count: 32),
                      "ffff" + String(repeating: "0", count: 52), String(repeating: "f", count: 64)])
    func boundaryIsInclusive(_ hex: String) {
        let t = target(hex: hex)
        let value = bytes(of: t.value)
        #expect(BlockHash(t.value).meetsTarget(t))
        #expect(BlockHash(hash(subtractingOne(value))).meetsTarget(t))
        if let above = addingOne(value) {
            #expect(!BlockHash(hash(above)).meetsTarget(t))
        }
    }

    /// Crossing the 128-bit word boundary in both directions.
    @Test func wordBoundary() {
        let twoTo128 = target(hex: "1" + String(repeating: "0", count: 32))
        #expect(block(hex: String(repeating: "f", count: 32)).meetsTarget(twoTo128))
        #expect(block(hex: "1" + String(repeating: "0", count: 32)).meetsTarget(twoTo128))
        #expect(!block(hex: "1" + String(repeating: "0", count: 31) + "1").meetsTarget(twoTo128))

        let justBelow = target(hex: String(repeating: "f", count: 32))
        #expect(!block(hex: "1" + String(repeating: "0", count: 32)).meetsTarget(justBelow))
    }

    /// Byte 31 is the most significant: it outweighs all 31 bytes below it.
    @Test func lastByteDominates() {
        var top = [UInt8](repeating: 0, count: 32)
        top[31] = 0x01
        var rest = [UInt8](repeating: 0xFF, count: 32)
        rest[31] = 0x00
        #expect(BlockHash(hash(rest)).meetsTarget(Target(hash(top))!))
        #expect(!BlockHash(hash(top)).meetsTarget(Target(hash(rest))!))
    }

    @Test func extremes() {
        let zero = BlockHash(hash([UInt8](repeating: 0, count: 32)))
        let maxHash = BlockHash(hash([UInt8](repeating: 0xFF, count: 32)))
        let minTarget = target(hex: "1"), maxTarget = target(hex: String(repeating: "f", count: 64))

        #expect(zero.meetsTarget(minTarget))
        #expect(block(hex: "1").meetsTarget(minTarget))
        #expect(!block(hex: "2").meetsTarget(minTarget))
        #expect(!maxHash.meetsTarget(minTarget))
        #expect(maxHash.meetsTarget(maxTarget))
        for pattern in BytePattern.all {
            #expect(BlockHash(hash(pattern.bytes)).meetsTarget(maxTarget), "\(pattern.name)")
        }
        for t in randomTargets(100, seed: 20) {
            #expect(zero.meetsTarget(t))
        }
    }

    @Test func agreesWithReferenceOnRandomPairs() {
        var rng = SplitMix64(seed: 21)
        for t in randomTargets(2_000, seed: 22) {
            let candidate = randomBytes(&rng)
            #expect(BlockHash(hash(candidate)).meetsTarget(t) == !referenceLess(bytes(of: t.value), candidate))
        }
    }

    /// Hashes one unit away from the target in a random byte, where comparisons are hardest.
    @Test func agreesWithReferenceOnNearPairs() {
        var rng = SplitMix64(seed: 23)
        for t in randomTargets(2_000, seed: 24) {
            var candidate = bytes(of: t.value)
            let index = Int.random(in: 0..<32, using: &rng)
            candidate[index] = Bool.random(using: &rng) ? candidate[index] &+ 1 : candidate[index] &- 1
            #expect(BlockHash(hash(candidate)).meetsTarget(t) == !referenceLess(bytes(of: t.value), candidate))
        }
    }

    /// `meetsTarget` and `Target`'s ordering are the same comparison.
    @Test func consistentWithTargetOrdering() {
        let targets = randomTargets(300, seed: 25)
        for (a, b) in zip(targets, targets.dropFirst()) {
            #expect(BlockHash(a.value).meetsTarget(b) == (a <= b))
        }
    }
}

@Suite("BlockHash.satisfiesProofOfWork")
struct SatisfiesProofOfWorkTests {
    private static let zero = BlockHash(hash([UInt8](repeating: 0, count: 32)))

    @Test func genesisAtNeighbouringDifficulties() {
        let genesis = BlockHash(doubleSHA256(Fixtures.genesisHeader))
        // 11 leading zero hex digits: meets 0x1c00ffff (10) but not 0x1b00ffff (12).
        #expect(genesis.satisfiesProofOfWork(compact: 0x1D00_FFFF, powLimit: Fixtures.mainnetPowLimit))
        #expect(genesis.satisfiesProofOfWork(compact: 0x1C00_FFFF, powLimit: Fixtures.mainnetPowLimit))
        #expect(!genesis.satisfiesProofOfWork(compact: 0x1B00_FFFF, powLimit: Fixtures.mainnetPowLimit))
    }

    @Test(arguments: [UInt32(0), 0x0100_3456, 0x0492_3456, 0xFF12_3456, 0x2301_0000])
    func invalidCompactFails(bits: UInt32) {
        #expect(!Self.zero.satisfiesProofOfWork(compact: bits, powLimit: Fixtures.regtestPowLimit))
    }

    /// A target above the limit fails even for a hash that would meet it.
    @Test func targetAbovePowLimitFails() {
        #expect(Self.zero.satisfiesProofOfWork(compact: 0x1D00_FFFF, powLimit: Fixtures.mainnetPowLimit))
        #expect(!Self.zero.satisfiesProofOfWork(compact: 0x1D01_0000, powLimit: Fixtures.mainnetPowLimit))
        #expect(!Self.zero.satisfiesProofOfWork(compact: 0x207F_FFFF, powLimit: Fixtures.mainnetPowLimit))
    }

    @Test func regtest() {
        #expect(Self.zero.satisfiesProofOfWork(compact: 0x207F_FFFF, powLimit: Fixtures.regtestPowLimit))
        #expect(block(hex: "7fffff" + String(repeating: "0", count: 58))
            .satisfiesProofOfWork(compact: 0x207F_FFFF, powLimit: Fixtures.regtestPowLimit))
        #expect(!block(hex: "7fffff" + String(repeating: "0", count: 57) + "1")
            .satisfiesProofOfWork(compact: 0x207F_FFFF, powLimit: Fixtures.regtestPowLimit))
    }
}
