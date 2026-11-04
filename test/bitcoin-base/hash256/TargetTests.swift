import Foundation
import BitcoinBase
import Testing

private func zeros(_ count: Int) -> String { String(repeating: "0", count: count) }
private let maxHex = String(repeating: "f", count: 64)

@Suite("Target")
struct TargetTests {
    @Suite struct Construction {
        @Test func zeroIsNeverATarget() {
            #expect(Target(hash([UInt8](repeating: 0, count: 32))) == nil)
            #expect(Target(hex: "0") == nil)
            #expect(Target(hex: "0x" + zeros(64)) == nil)
            #expect(Target(compact: 0) == nil)
            #expect(Target(bits: "00000000") == nil)
            #expect(Target(difficulty: .greatestFiniteMagnitude) == nil)
        }

        @Test(arguments: BytePattern.nonZero)
        func wrapsAnyNonZeroValue(_ pattern: BytePattern) throws {
            let target = try #require(Target(hash(pattern.bytes)))
            #expect(bytes(of: target.value) == pattern.bytes)
        }

        @Test func difficultyOne() {
            #expect(Target.difficultyOne.hex == "0x00000000ffff" + zeros(52))
            #expect(Target.difficultyOne.compact == 0x1D00_FFFF)
            #expect(Target.difficultyOne.difficulty == 1)
            #expect(Target.difficultyOne <= Fixtures.mainnetPowLimit)
        }
    }

    @Suite struct Ordering {
        @Test func agreesWithReference() {
            let targets = randomTargets(1_000, seed: 30)
            for (a, b) in zip(targets, targets.dropFirst()) {
                let reference = referenceLess(bytes(of: a.value), bytes(of: b.value))
                #expect((a < b) == reference)
                #expect((a > b) == referenceLess(bytes(of: b.value), bytes(of: a.value)))
                #expect((a == b) == (bytes(of: a.value) == bytes(of: b.value)))
            }
        }

        @Test func sortsLikeTheReference() {
            let targets = randomTargets(500, seed: 31) + BytePattern.nonZero.map { Target(hash($0.bytes))! }
            let expected = targets.map { bytes(of: $0.value) }.sorted(by: referenceLess)
            #expect(targets.sorted().map { bytes(of: $0.value) } == expected)
        }

        @Test func irreflexiveAndTotal() {
            for t in randomTargets(200, seed: 32) {
                #expect(!(t < t))
                #expect(t <= t && t >= t)
            }
        }

        @Test func extremesAndWordBoundary() {
            let one = Target(hex: "1")!, max = Target(hex: maxHex)!
            let below = Target(hex: String(repeating: "f", count: 32))!, boundary = Target(hex: "1" + zeros(32))!
            #expect(one < below && below < boundary && boundary < max)
            for t in randomTargets(200, seed: 33) {
                #expect(one <= t && t <= max)
            }
        }
    }

    @Suite struct Hashing {
        /// Compact targets have zeros in the 8 bytes `Hash256` hashes, so `Target` hashes all 32.
        @Test func compactTargetsHashApart() {
            // 500 distinct valid compacts: exponents 0x17...0x1d, mantissas from 0x010000 upward.
            let targets: [Target] = (0..<500).map { (i: Int) -> Target in
                let exponent = Int(0x17 + i % 7) << 24
                let mantissa = Int(0x01_0000 + i * 97)
                return Target(compact: exponent | mantissa)!
            }
            let hashValues: Set<Int> = Set(targets.map { (target: Target) -> Int in target.hashValue })
            #expect(Set(targets).count == targets.count)
            #expect(hashValues.count == targets.count)
        }

        @Test func equalTargetsHashEqually() {
            for t in randomTargets(100, seed: 112) {
                #expect(Target(hex: t.hex)!.hashValue == t.hashValue)
            }
        }
    }

    @Suite struct CompactDecoding {
        /// Bitcoin Core's `arith_uint256_tests` (SetCompact) plus exponent and overflow boundaries.
        @Test(arguments: [
            (Int(0x0112_3456), "12"),
            (0x0212_3456, "1234"),
            (0x0312_3456, "123456"),
            (0x0412_3456, "12345600"),
            (0x0200_8000, "80"),
            (0x0500_9234, "92340000"),
            (0x2012_3456, "123456" + String(repeating: "0", count: 58)),
            (0x1D00_FFFF, "ffff" + String(repeating: "0", count: 52)),
            (0x207F_FFFF, "7fffff" + String(repeating: "0", count: 58)),
            (0x2100_FFFF, "ffff" + String(repeating: "0", count: 60)),   // 2 bytes at exponent 33
            (0x2200_00FF, "ff" + String(repeating: "0", count: 62)),     // 1 byte at exponent 34
            (0x0101_0000, "1"),                                          // the smallest target
        ] as [(Int, String)])
        func decodes(bits: Int, expectedHex: String) throws {
            let target = try #require(Target(compact: bits))
            #expect(target == Target(hex: expectedHex))
        }

        @Test(arguments: [
            Int(0x0000_0000),  // zero
            0x0012_3456,  // exponent 0 shifts everything away
            0x0100_3456,  // exponent 1 shifts the low bytes away
            0x0180_0000,  // negative zero
            0x0492_3456,  // negative
            0x20FF_FFFF,  // negative
            0x2201_0000,  // 2 bytes at exponent 34
            0x2101_0000,  // 3 bytes at exponent 33
            0x2300_00FF,  // exponent 35
            0xFF12_3456,  // overflow
        ])
        func rejects(bits: Int) {
            #expect(Target(compact: bits) == nil)
        }

        @Test func powLimitIsInclusive() {
            let limit = Target.difficultyOne
            #expect(Target(compact: 0x1D00_FFFF, powLimit: limit) == limit)
            #expect(Target(compact: 0x1C00_FFFF, powLimit: limit) != nil)
            #expect(Target(compact: 0x1D01_0000, powLimit: limit) == nil)
            #expect(Target(compact: 0x1D00_FFFF, powLimit: Target(compact: 0x1D00_FFFE)!) == nil)
        }
    }

    /// `compact` is an `Int`, like swift-bitcoin's header fields; `nBits` is still 32 bits.
    @Suite struct CompactAsInt {
        @Test(arguments: [-1, Int(Int32.min), Int.min, 0x1_0000_0000, 0x1_1D00_FFFF, Int.max])
        func outOfRangeIsInvalid(bits: Int) {
            #expect(Target(compact: bits) == nil)
            #expect(!BlockHash(Hash256.zero).satisfiesProofOfWork(compact: bits, powLimit: Fixtures.regtestPowLimit))
        }

        /// Not truncated: 0x1_1d00ffff isn't read as 0x1d00ffff.
        @Test func noTruncation() {
            #expect(Target(compact: 0x1D00_FFFF) != nil)
            #expect(Target(compact: 0x1_1D00_FFFF) == nil)
        }

        /// Every valid nBits is below 0x2300_0000, so `compact` fits even a 32-bit `Int`.
        @Test func validCompactFitsInt32() {
            var rng = SplitMix64(seed: 150)
            for _ in 0..<5_000 {
                let bits = Int(UInt32.random(in: 0 ... .max, using: &rng))
                if let target = Target(compact: bits) {
                    #expect(bits < 0x2300_0000)
                    #expect(target.compact < 0x2300_0000)
                }
            }
            #expect(Target(hex: String(repeating: "f", count: 64))!.compact == 0x2100_FFFF)
        }

        @Test func bitsStringStaysEightDigits() {
            #expect(Target.difficultyOne.bits == "1d00ffff")
            #expect(Target(compact: 0x1B04_04CB)?.bits == "1b0404cb")
            #expect(Target(compact: 0x0101_0000)?.bits == "01010000")  // leading zero digit kept
        }
    }

    @Suite struct CompactEncoding {
        /// Decode then re-encode: Bitcoin Core's GetCompact normalizes non-canonical encodings.
        @Test(arguments: [
            (Int(0x0112_3456), Int(0x0112_0000)),
            (0x0212_3456, 0x0212_3400),
            (0x0312_3456, 0x0312_3456),
            (0x0412_3456, 0x0412_3456),
            (0x0400_3456, 0x0334_5600),
            (0x0200_8000, 0x0200_8000),
            (0x0500_9234, 0x0500_9234),
            (0x2012_3456, 0x2012_3456),
            (0x1D00_FFFF, 0x1D00_FFFF),
            (0x207F_FFFF, 0x207F_FFFF),
        ])
        func normalizes(bits: Int, encoded: Int) {
            #expect(Target(compact: bits)!.compact == encoded)
            #expect(Target(compact: encoded) == Target(compact: bits))
        }

        /// A single significant byte at every position encodes exactly.
        @Test(arguments: 0..<32)
        func singleByteAtEveryPosition(position: Int) throws {
            var value = [UInt8](repeating: 0, count: 32)
            value[position] = 0x01
            let target = try #require(Target(hash(value)))
            #expect(target.compact == Int(position + 1) << 24 | 0x01_0000)
            #expect(Target(compact: target.compact) == target)
        }

        /// A top byte of 0x80 or more would set the sign bit, so it moves into the next byte.
        @Test(arguments: 0..<32)
        func avoidsTheSignBit(position: Int) throws {
            var value = [UInt8](repeating: 0, count: 32)
            value[position] = 0x80
            let target = try #require(Target(hash(value)))
            #expect(target.compact == Int(position + 2) << 24 | 0x00_8000)
            #expect(Target(compact: target.compact) == target)
        }

        @Test func maximumTarget() {
            let max = Target(hex: maxHex)!
            #expect(max.compact == 0x2100_FFFF)
            #expect(Target(compact: max.compact)! < max)
        }

        /// Encoding keeps the top 2–3 bytes, rounds down, never sets the sign bit, and is stable.
        @Test func lossyButStable() throws {
            for t in randomTargets(2_000, seed: 34) {
                let compact = t.compact
                #expect(compact & 0x0080_0000 == 0)
                let decoded = try #require(Target(compact: compact))
                #expect(bytes(of: decoded.value) == referenceCompactTruncation(bytes(of: t.value)))
                #expect(decoded <= t)
                #expect(decoded.compact == compact)
            }
        }
    }

    @Suite struct BitsString {
        @Test(arguments: [
            ("1d00ffff", Int(0x1D00_FFFF)), ("0x1d00ffff", 0x1D00_FFFF), ("0X1D00FFFF", 0x1D00_FFFF),
            ("1D00ffFF", 0x1D00_FFFF), ("207fffff", 0x207F_FFFF), ("3123456", 0x0312_3456), ("1010000", 0x0101_0000),
        ])
        func parses(text: String, compact: Int) {
            #expect(Target(bits: text) == Target(compact: compact))
        }

        @Test(arguments: [
            "", "0x", "1d00ffff0", "0x1d00ffff0", "+1d00fff", "-1d00fff", " 1d00ffff", "1d00ffff ",
            "1d00fffg", "0x0x1d00ff", "00000000", "ffffffff", "04923456", "\u{FF11}d00ffff",
        ])
        func rejects(text: String) {
            #expect(Target(bits: text) == nil)
        }

        @Test func formatsAsEightLowercaseDigits() {
            #expect(Target.difficultyOne.bits == "1d00ffff")
            #expect(Target(hex: "1")!.bits == "01010000")
            #expect(Target(compact: 0x0200_8000)!.bits == "02008000")
            for t in randomTargets(500, seed: 35) {
                #expect(t.bits.count == 8)
                #expect(t.bits == t.bits.lowercased())
                #expect(Target(bits: t.bits) == Target(compact: t.compact))
            }
        }
    }

    @Suite struct HexString {
        @Test(arguments: BytePattern.nonZero)
        func roundTrips(_ pattern: BytePattern) throws {
            let target = try #require(Target(hash(pattern.bytes)))
            #expect(target.hex.count == 66)
            #expect(target.hex.hasPrefix("0x"))
            #expect(target.hex == target.hex.lowercased())
            #expect(target.description == target.hex)
            #expect(target.hex == "0x" + target.value.displayHex)
            #expect(Target(hex: target.hex) == target)
            #expect(Target(hex: String(target.hex.dropFirst(2))) == target)
            #expect(Target(hex: target.hex.uppercased().replacingOccurrences(of: "0X", with: "0x")) == target)
        }

        @Test func randomRoundTrips() {
            for t in randomTargets(1_000, seed: 36) {
                #expect(Target(hex: t.hex) == t)
            }
        }

        /// Short strings are zero-extended on the left; leading zeros don't change the value.
        @Test func zeroExtends() {
            #expect(Target(hex: "1")!.hex == "0x" + zeros(63) + "1")
            #expect(Target(hex: "0x1") == Target(hex: zeros(63) + "1"))
            #expect(Target(hex: "ffff" + zeros(52)) == .difficultyOne)
            #expect(Target(hex: "1" + zeros(32))!.hex == "0x" + zeros(31) + "1" + zeros(32))
        }

        @Test(arguments: [
            "", "0x", "0X", "0", "0x0", "0x" + String(repeating: "0", count: 64),
            String(repeating: "f", count: 65), "0x" + String(repeating: "f", count: 65),
            "-1", "+1", " 1", "1 ", "0xg", "12 34", "0x0x1", "\u{FF11}",
        ])
        func rejects(text: String) {
            #expect(Target(hex: text) == nil)
        }
    }

    @Suite struct BigEndianBytes {
        /// The network limits as swift-bitcoin's `ConsensusParams` stores them.
        @Test func networkLimits() {
            let mainnet = [UInt8](repeating: 0, count: 4) + [UInt8](repeating: 0xFF, count: 28)
            let regtest = [0x7F] + [UInt8](repeating: 0xFF, count: 31)
            let signet = [0x00, 0x00, 0x03, 0x77, 0xAE] + [UInt8](repeating: 0, count: 27)
            #expect(Target(bigEndianBytes: mainnet) == Fixtures.mainnetPowLimit)
            #expect(Target(bigEndianBytes: Data(mainnet)) == Fixtures.mainnetPowLimit)
            #expect(Target(bigEndianBytes: regtest) == Fixtures.regtestPowLimit)
            #expect(Target(bigEndianBytes: signet) == Target(hex: "00000377ae" + zeros(54)))
            #expect(Target(bigEndianBytes: signet)?.compact == 0x1E03_77AE)
        }

        /// Big-endian bytes are the hex digits read as bytes: the reverse of the stored order.
        @Test func matchesHexForRandomTargets() {
            for t in randomTargets(500, seed: 130) {
                let bigEndian = bytes(fromHex: String(t.hex.dropFirst(2)))
                #expect(Target(bigEndianBytes: bigEndian) == t)
                #expect(bigEndian == Array(bytes(of: t.value).reversed()))
            }
        }

        @Test(arguments: [0, 1, 31, 33, 64])
        func rejectsWrongLength(count: Int) {
            #expect(Target(bigEndianBytes: [UInt8](repeating: 0x01, count: count)) == nil)
        }

        @Test func rejectsZero() {
            #expect(Target(bigEndianBytes: [UInt8](repeating: 0, count: 32)) == nil)
            #expect(Target(bigEndianBytes: InlineArray<32, UInt8>(repeating: 0)) == nil)
        }

        /// A 32-byte literal typed as an `InlineArray`: the motivating case.
        @Test func inlineArrayLiteral() {
            let mainnet: InlineArray<32, UInt8> = [
                0x00, 0x00, 0x00, 0x00, 0xFF, 0xFF, 0xFF, 0xFF, 0xFF, 0xFF, 0xFF, 0xFF, 0xFF, 0xFF, 0xFF, 0xFF,
                0xFF, 0xFF, 0xFF, 0xFF, 0xFF, 0xFF, 0xFF, 0xFF, 0xFF, 0xFF, 0xFF, 0xFF, 0xFF, 0xFF, 0xFF, 0xFF,
            ]
            #expect(Target(bigEndianBytes: mainnet) == Fixtures.mainnetPowLimit)
            // Unlabelled, the same bytes are read little-endian: a different target entirely.
            #expect(Target(Hash256(mainnet)) != Fixtures.mainnetPowLimit)
        }

        /// An untyped literal still resolves (to the `Collection` overload) and gives the same value.
        @Test func untypedLiteralResolves() {
            let target = Target(bigEndianBytes: [
                0x7F, 0xFF, 0xFF, 0xFF, 0xFF, 0xFF, 0xFF, 0xFF, 0xFF, 0xFF, 0xFF, 0xFF, 0xFF, 0xFF, 0xFF, 0xFF,
                0xFF, 0xFF, 0xFF, 0xFF, 0xFF, 0xFF, 0xFF, 0xFF, 0xFF, 0xFF, 0xFF, 0xFF, 0xFF, 0xFF, 0xFF, 0xFF,
            ])
            #expect(target == Fixtures.regtestPowLimit)
        }

        @Test func inlineArrayMatchesCollection() {
            for t in randomTargets(500, seed: 134) {
                let bigEndian = bytes(fromHex: String(t.hex.dropFirst(2)))
                #expect(Target(bigEndianBytes: InlineArray<32, UInt8> { bigEndian[$0] }) == t)
            }
            var single = [UInt8](repeating: 0, count: 32)
            for i in 0..<32 {  // a single set bit at every byte position
                single[i] = 0x01
                #expect(Target(bigEndianBytes: InlineArray<32, UInt8> { single[$0] })
                        == Target(bigEndianBytes: single))
                single[i] = 0
            }
        }
    }

    @Suite struct Difficulty {
        /// Expected values computed exactly with Python's `fractions`; compact targets convert to
        /// `Double` exactly, so the division is correctly rounded and the match is exact.
        @Test(arguments: [
            (Int(0x1D00_FFFF), 1.0),
            (0x1C00_FFFF, 256.0),
            (0x1B00_FFFF, 65536.0),
            (0x1D01_FFFE, 0.5),
            (0x1B04_04CB, 16307.420938523983),
            (0x1F11_1111, 8.94056082500228e-07),
            (0x1D00_D86A, 1.1828995343128408),
            (0x1A05_DB8B, 2864140.5078109736),
            (0x1903_A30C, 1180923195.2580261),
            (0x1806_B99F, 163491654908.95926),
            (0x1234_5678, 5.913134931067755e+24),
            (0x1703_4219, 86388558925171.02),
            (0x207F_FFFF, 4.6565423739069247e-10),
            (0x0101_0000, 2.695953529101131e+67),
            (0x2100_FFFF, 2.3283064365386963e-10),
        ])
        func fromCompact(bits: Int, expected: Double) {
            #expect(Target(compact: bits)!.difficulty == expected)
        }

        /// The maximum target's difficulty maps back to 2²⁵⁶ in a Double, which is clamped to the maximum.
        @Test func maximumTarget() {
            let max = Target(hex: maxHex)!
            #expect(abs(max.difficulty - 2.3282709094019083e-10) <= 1e-15 * 2.3282709094019083e-10)
            #expect(Target(difficulty: max.difficulty) == max)
            #expect(Target(difficulty: 0x1p-32) == Target(hex: "ffff" + zeros(60)))
            #expect(Target(difficulty: max.difficulty.nextDown) == nil)
        }

        /// Bitcoin Core's `blockchain_tests` vectors for `GetDifficulty`, which swift-bitcoin's
        /// `BlockchainServiceTests.difficulty` ports.
        @Test(arguments: [
            (0x1f11_1111, 0.000001),
            (0x1ef8_8f6f, 0.000016),
            (0x1df8_8f6f, 0.004023),
            (0x1cf8_8f6f, 1.029916),
            (0x1234_5678, 5_913_134_931_067_755_359_633_408.0),
        ])
        func coreGetDifficultyVectors(bits: Int, expected: Double) throws {
            let difficulty = try #require(Target.difficulty(compact: bits))
            #expect(abs(difficulty - expected) < 0.000_01 || abs(difficulty / expected - 1) < 1e-15)
        }

        /// The same arguments as core and the same absolute tolerance.
        /// `isApproximatelyEqual(_:to:absoluteTolerance:)` is `abs(a - b) <= tolerance` there.
        @Test(arguments: [
            ("very_low_target", 0x1f111111, 0.000001),
            ("low_target", 0x1ef88f6f, 0.000016),
            ("mid_target", 0x1df88f6f, 0.004023),
            ("high_target", 0x1cf88f6f, 1.029916),
            ("very_high_target", 0x12345678, 5913134931067755359633408.0),
        ])
        func swiftBitcoinDifficulty(name: String, compact: Int, expected: Double) throws {
            let difficulty = try #require(Target.difficulty(compact: compact))
            #expect(abs(difficulty - expected) <= 0.00001)
            if let target = Target(compact: compact) {
                #expect(target.compact == compact)
            }
        }

        @Test func negativeVectorsDontDecode() {
            for bits in [0x1ef8_8f6f, 0x1df8_8f6f, 0x1cf8_8f6f] {
                #expect(Target(compact: bits) == nil)
            }
        }

        @Test(arguments: [0x1f11_1111, 0x1234_5678, 0x1d00_ffff, 0x207f_ffff, 0x1703_a30c, 0x0101_0000, 0x2200_0001])
        func compactDifficultyMatchesTheTargets(bits: Int) throws {
            let target = try #require(Target(compact: bits))
            let difficulty = try #require(Target.difficulty(compact: bits))
            #expect(abs(difficulty / target.difficulty - 1) < 1e-12)
        }

        @Test(arguments: [-1, 0x1_0000_0000, 0, 0x1d00_0000, 0xff00_0000])
        func compactDifficultyRejects(bits: Int) {
            #expect(Target.difficulty(compact: bits) == nil)
        }

        @Test func harderTargetsHaveHigherDifficulty() {
            let targets = randomTargets(300, seed: 37).sorted()
            for (easier, harder) in zip(targets.dropFirst(), targets) {
                #expect(harder.difficulty >= easier.difficulty)
            }
        }

        @Test(arguments: [
            (1.0, Int(0x1D00_FFFF)), (256.0, 0x1C00_FFFF), (65536.0, 0x1B00_FFFF), (0.5, 0x1D01_FFFE),
        ])
        func toTargetExactly(difficulty: Double, compact: Int) {
            #expect(Target(difficulty: difficulty) == Target(compact: compact))
        }

        /// The range of valid difficulties: from a target just under 2²⁵⁶ down to a target of 1.
        @Test func limits() {
            #expect(Target(difficulty: 0x1p-31) == Target(hex: "7fff80" + zeros(58)))  // 0xffff << 239
            #expect(Target(difficulty: 0x1p-33) == nil)
            #expect(Target(difficulty: 0xFFFF * 0x1p208) == Target(hex: "1"))
            #expect(Target(difficulty: 0xFFFF * 0x1p209) == nil)
        }

        @Test(arguments: [0.0, -0.0, -1.0, -.infinity, .infinity, .nan, .leastNonzeroMagnitude, 1e-80, 1e80])
        func rejects(difficulty: Double) {
            #expect(Target(difficulty: difficulty) == nil)
        }

        /// Difficulty → target → difficulty, over 1e-9 ... 1e40 (targets large enough that
        /// rounding the target down to an integer costs no precision).
        @Test func roundTripsThroughDouble() throws {
            var rng = SplitMix64(seed: 38)
            for _ in 0..<1_000 {
                let difficulty = pow(10, Double.random(in: -9...40, using: &rng))
                let back = try #require(Target(difficulty: difficulty)).difficulty
                #expect(abs(back - difficulty) <= 1e-14 * difficulty)
            }
        }

        /// Real mainnet compacts through difficulty and back: the target is within a Double's
        /// precision, and the compact is unchanged or one mantissa step lower.
        @Test(arguments: [Int(0x1D00_FFFF), 0x1D00_D86A, 0x1C00_FFFF, 0x1B04_04CB, 0x1A05_DB8B,
                          0x1903_A30C, 0x1806_B99F, 0x1703_4219, 0x207F_FFFF])
        func compactThroughDifficulty(bits: Int) throws {
            let target = try #require(Target(compact: bits))
            let back = try #require(Target(difficulty: target.difficulty))
            #expect(back <= target)
            #expect(abs(back.difficulty - target.difficulty) <= 1e-15 * target.difficulty)
            #expect(back.compact == bits || back.compact == bits - 1)
        }

        /// The case that motivated the documentation: 0x1d00d86a comes back one step lower.
        @Test func difficultyIsLossy() {
            #expect(Target(difficulty: Target(compact: 0x1D00_D86A)!.difficulty)?.compact == 0x1D00_D869)
        }
    }

    @Suite struct Retargeting {
        private static let twoWeeks = 14 * 24 * 60 * 60

        /// Bitcoin Core's `pow_tests.cpp`: last block's bits, the period's first and last block
        /// times, and the expected next bits. Rechecked with Python's exact integers.
        @Test(arguments: [
            (Int(0x1D00_FFFF), 1_261_130_161, 1_262_152_739, Int(0x1D00_D86A)),  // get_next_work
            (0x1D00_FFFF, 1_231_006_505, 1_233_061_996, 0x1D00_FFFF),  // capped at powLimit
            (0x1C05_A3F4, 1_279_008_237, 1_279_297_671, 0x1C01_68FD),  // timespan clamped up to ¼
            (0x1C38_7F6F, 1_263_163_443, 1_269_211_443, 0x1D00_E1FD),  // timespan clamped down to 4×
        ] as [(Int, Int, Int, Int)])
        func matchesBitcoinCore(bits: Int, firstTime: Int, lastTime: Int, expected: Int) throws {
            let target = try #require(Target(compact: bits))
            let next = target.retargeted(
                actualTimespan: lastTime - firstTime, targetTimespan: Self.twoWeeks, powLimit: Fixtures.mainnetPowLimit)
            #expect(next?.compact == expected)
        }

        /// The first retarget, block 32,256: what swift-bitcoin's header check compares against.
        @Test func firstMainnetRetarget() {
            let next = Target.difficultyOne.retargeted(
                actualTimespan: 1_022_578, targetTimespan: Self.twoWeeks, powLimit: Fixtures.mainnetPowLimit)
            #expect(next?.bits == "1d00d86a")
        }

        /// Holds while `target × timespan` fits in 256 bits, as it always does under mainnet's limit.
        @Test func targetTimespanLeavesTheTargetUnchanged() {
            for t in randomTargets(200, seed: 140) where t <= Fixtures.mainnetPowLimit {
                #expect(t.retargeted(actualTimespan: Self.twoWeeks, targetTimespan: Self.twoWeeks,
                                     powLimit: Fixtures.mainnetPowLimit) == t)
            }
        }

        /// Past that, Core's product wraps, so even an on-schedule period changes the target.
        @Test func targetTimespanChangesAWrappingTarget() {
            let limit = Fixtures.regtestPowLimit
            #expect(limit.retargeted(actualTimespan: Self.twoWeeks, targetTimespan: Self.twoWeeks, powLimit: limit) != limit)
        }

        /// Outside ¼ ... 4× of the target timespan, the timespan is clamped first, even when negative
        /// (block times may go backwards).
        @Test func clampsTheTimespan() {
            let t = Target(compact: 0x1B04_04CB)!, limit = Fixtures.mainnetPowLimit, span = Self.twoWeeks
            let quarter = t.retargeted(actualTimespan: span / 4, targetTimespan: span, powLimit: limit)
            let fourTimes = t.retargeted(actualTimespan: span * 4, targetTimespan: span, powLimit: limit)
            for shorter in [span / 4 - 1, 1, 0, -span] {
                #expect(t.retargeted(actualTimespan: shorter, targetTimespan: span, powLimit: limit) == quarter)
            }
            for longer in [span * 4 + 1, span * 100, Int(Int32.max)] {
                #expect(t.retargeted(actualTimespan: longer, targetTimespan: span, powLimit: limit) == fourTimes)
            }
        }

        /// An `nBits` equal to the expected value always passes the `powLimit` check: the retarget
        /// caps at the limit and `compact` rounds down. So, once a header's `nBits` is checked
        /// against the expected value, checking it against `powLimit` again is redundant.
        @Test func expectedBitsAlwaysDecodeUnderThePowLimit() {
            for limit in [Fixtures.mainnetPowLimit, Fixtures.regtestPowLimit] {
                #expect(Target(compact: limit.compact, powLimit: limit) != nil)  // min-difficulty blocks
                for t in randomTargets(500, seed: 142) where t <= limit {
                    for span in [Self.twoWeeks / 4, Self.twoWeeks, Self.twoWeeks * 4] {
                        guard let next = t.retargeted(actualTimespan: span, targetTimespan: Self.twoWeeks, powLimit: limit)
                        else { continue }
                        #expect(Target(compact: next.compact, powLimit: limit) != nil)
                    }
                }
            }
        }

        @Test func neverExceedsThePowLimit() {
            let limit = Fixtures.mainnetPowLimit
            for t in randomTargets(300, seed: 141) where t <= limit {
                let next = t.retargeted(actualTimespan: Self.twoWeeks * 4, targetTimespan: Self.twoWeeks, powLimit: limit)
                #expect(next.map { $0 <= limit } ?? true)
            }
        }

        /// Like Core's `arith_uint256`, the product wraps modulo 2²⁵⁶ before the division.
        /// Expected values from Python's integers: `(t * timespan % 2**256) // span`.
        @Test func productWrapsLikeCore() {
            let limit = Fixtures.regtestPowLimit
            // Regtest's limit × 4 days wraps; the quotient is far below the limit, not capped to it.
            #expect(limit.retargeted(actualTimespan: 4 * 86_400, targetTimespan: 86_400, powLimit: limit)
                    == Target(hex: "0000c22e450672894ab6cd8efb11d33f5617839a5bc7dea00c22e450672894a7"))
            // 0x207fffff × 960 s ÷ 600 s.
            #expect(Target(compact: 0x207F_FFFF)!.retargeted(actualTimespan: 960, targetTimespan: 600, powLimit: limit)
                    == Target(hex: "006d386d3a06d3a06d3a06d3a06d3a06d3a06d3a06d3a06d3a06d3a06d3a06d3"))
        }

        /// A product that wraps to exactly 0 mod 2²⁵⁶ gives no target, which Core encodes as compact 0.
        @Test func productWrappingToZeroIsNil() {
            let maximum = Target(hex: String(repeating: "f", count: 64))!
            // 2²⁵⁰ × 2²² = 2²⁷² and 2²⁵⁴ × 2²² = 2²⁷⁶ are both 0 mod 2²⁵⁶.
            #expect(Target(hex: "4" + zeros(62))!.retargeted(actualTimespan: 4 * 1_048_576, targetTimespan: 1_048_576,
                                                            powLimit: Fixtures.regtestPowLimit) == nil)
            #expect(Target(hex: "4" + zeros(63))!.retargeted(actualTimespan: 4 * 1_048_576, targetTimespan: 1_048_576,
                                                            powLimit: maximum) == nil)
        }

        /// swift-bitcoin's `BlockchainServiceTests.difficultyAdjustment`: regtest's limit, a
        /// 10-minute timespan and 2-minute spacing (so a retarget every 5 blocks), 15 blocks at
        /// 4, then 2, then 4 minutes apart. Its expected bits are Bitcoin Core's wrapped results.
        @Test func swiftBitcoinDifficultyAdjustment() {
            let limit = Fixtures.regtestPowLimit, span = 600
            let first = Target(compact: 0x207F_FFFF)!
            let second = first.retargeted(actualTimespan: 4 * 240, targetTimespan: span, powLimit: limit)
            #expect(second?.compact == 0x1F6D_386D)
            let third = second?.retargeted(actualTimespan: 4 * 120, targetTimespan: span, powLimit: limit)
            #expect(third?.compact == 0x1F57_6057)
            let fourth = third?.retargeted(actualTimespan: 4 * 240, targetTimespan: span, powLimit: limit)
            #expect(fourth?.compact == 0x1F1E_9351)
        }

        /// Only targets below 4 can round down to zero; Core would encode that as compact 0.
        @Test func zeroResultIsNil() {
            let limit = Fixtures.mainnetPowLimit, span = Self.twoWeeks
            #expect(Target(hex: "3")!.retargeted(actualTimespan: span / 4, targetTimespan: span, powLimit: limit) == nil)
            #expect(Target(hex: "4")!.retargeted(actualTimespan: span / 4, targetTimespan: span, powLimit: limit) == Target(hex: "1"))
        }

        /// Against a reference built from the test suite's own 64-bit limb arithmetic. Random
        /// targets up to 2²⁵⁶ with regtest's limit, so many products wrap.
        @Test func matchesReferenceArithmetic() {
            var rng = SplitMix64(seed: 142)
            let limit = Fixtures.regtestPowLimit
            for t in randomTargets(1_000, seed: 143) {
                let span = Int.random(in: 1...3_000_000, using: &rng)
                let actual = Int.random(in: -span...(5 * span), using: &rng)
                let clamped = UInt64(min(max(actual, span / 4), span * 4))
                // Core: the product wraps to 256 bits, then the division.
                let product = Array(multiply(limbs(bytes(of: t.value)), [clamped])[0..<4])
                let quotient = divide(product, by: UInt64(span))
                let value = quotient.flatMap { limb in (0..<8).map { UInt8(truncatingIfNeeded: limb >> (8 * $0)) } }
                let expected = Target(hash(value)).map { min($0, limit) }
                #expect(t.retargeted(actualTimespan: actual, targetTimespan: span, powLimit: limit) == expected)
            }
        }

        @Test func trapsOnNonPositiveTargetTimespan() async {
            await #expect(processExitsWith: .failure) {
                _ = Target.difficultyOne.retargeted(actualTimespan: 1, targetTimespan: 0, powLimit: .difficultyOne)
            }
        }
    }

    /// Every format, back and forth, for limits and real values.
    @Suite struct AllFormats {
        static let samples: [String] = {
            var samples = ["1", "ff", "100", "ffffff", "1000000", "ffffffffffffffff"]
            samples.append(String(repeating: "f", count: 32))  // 2¹²⁸ − 1
            samples.append("1" + zeros(32))  // 2¹²⁸
            samples.append("8" + zeros(63))  // 2²⁵⁵
            samples.append(String(repeating: "f", count: 64))  // the maximum
            samples.append("ffff" + zeros(52))  // difficulty one
            samples.append("7fffff" + zeros(58))  // regtest limit
            samples.append(String(repeating: "f", count: 56))  // mainnet limit
            samples.append("34219" + zeros(40))  // a 2011-era target
            return samples
        }()

        @Test(arguments: samples)
        func agree(_ hex: String) throws {
            let target = try #require(Target(hex: hex))
            let compactTarget = try #require(Target(compact: target.compact))

            #expect(Target(hex: target.hex) == target)
            #expect(Target(target.value) == target)
            #expect(Target(bits: target.bits) == compactTarget)
            #expect(bytes(of: compactTarget.value) == referenceCompactTruncation(bytes(of: target.value)))
            #expect(compactTarget.compact == target.compact)
            #expect(target.work == Chainwork(target: target))

            // Difficulty → target rounds down to an integer, so only large targets keep full precision.
            if target > Target(hex: "1" + String(repeating: "0", count: 16))! {
                let viaDifficulty = try #require(Target(difficulty: target.difficulty))
                #expect(abs(viaDifficulty.difficulty - target.difficulty) <= 1e-12 * target.difficulty)
            }
        }
    }
}
