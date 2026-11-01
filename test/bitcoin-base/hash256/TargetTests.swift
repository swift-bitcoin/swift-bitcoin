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
                let exponent = UInt32(0x17 + i % 7) << 24
                let mantissa = UInt32(0x01_0000 + i * 97)
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
            (UInt32(0x0112_3456), "12"),
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
        ] as [(UInt32, String)])
        func decodes(bits: UInt32, expectedHex: String) throws {
            let target = try #require(Target(compact: bits))
            #expect(target == Target(hex: expectedHex))
        }

        @Test(arguments: [
            UInt32(0x0000_0000),  // zero
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
        func rejects(bits: UInt32) {
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

    @Suite struct CompactEncoding {
        /// Decode then re-encode: Bitcoin Core's GetCompact normalizes non-canonical encodings.
        @Test(arguments: [
            (UInt32(0x0112_3456), UInt32(0x0112_0000)),
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
        func normalizes(bits: UInt32, encoded: UInt32) {
            #expect(Target(compact: bits)!.compact == encoded)
            #expect(Target(compact: encoded) == Target(compact: bits))
        }

        /// A single significant byte at every position encodes exactly.
        @Test(arguments: 0..<32)
        func singleByteAtEveryPosition(position: Int) throws {
            var value = [UInt8](repeating: 0, count: 32)
            value[position] = 0x01
            let target = try #require(Target(hash(value)))
            #expect(target.compact == UInt32(position + 1) << 24 | 0x01_0000)
            #expect(Target(compact: target.compact) == target)
        }

        /// A top byte of 0x80 or more would set the sign bit, so it moves into the next byte.
        @Test(arguments: 0..<32)
        func avoidsTheSignBit(position: Int) throws {
            var value = [UInt8](repeating: 0, count: 32)
            value[position] = 0x80
            let target = try #require(Target(hash(value)))
            #expect(target.compact == UInt32(position + 2) << 24 | 0x00_8000)
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
            ("1d00ffff", UInt32(0x1D00_FFFF)), ("0x1d00ffff", 0x1D00_FFFF), ("0X1D00FFFF", 0x1D00_FFFF),
            ("1D00ffFF", 0x1D00_FFFF), ("207fffff", 0x207F_FFFF), ("3123456", 0x0312_3456), ("1010000", 0x0101_0000),
        ])
        func parses(text: String, compact: UInt32) {
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

    @Suite struct Difficulty {
        /// Expected values computed exactly with Python's `fractions`; compact targets convert to
        /// `Double` exactly, so the division is correctly rounded and the match is exact.
        @Test(arguments: [
            (UInt32(0x1D00_FFFF), 1.0),
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
        func fromCompact(bits: UInt32, expected: Double) {
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

        @Test func harderTargetsHaveHigherDifficulty() {
            let targets = randomTargets(300, seed: 37).sorted()
            for (easier, harder) in zip(targets.dropFirst(), targets) {
                #expect(harder.difficulty >= easier.difficulty)
            }
        }

        @Test(arguments: [
            (1.0, UInt32(0x1D00_FFFF)), (256.0, 0x1C00_FFFF), (65536.0, 0x1B00_FFFF), (0.5, 0x1D01_FFFE),
        ])
        func toTargetExactly(difficulty: Double, compact: UInt32) {
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
        @Test(arguments: [UInt32(0x1D00_FFFF), 0x1D00_D86A, 0x1C00_FFFF, 0x1B04_04CB, 0x1A05_DB8B,
                          0x1903_A30C, 0x1806_B99F, 0x1703_4219, 0x207F_FFFF])
        func compactThroughDifficulty(bits: UInt32) throws {
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
