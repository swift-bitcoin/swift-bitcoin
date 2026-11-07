import BinaryParsing
import BitcoinBase
import Foundation
import Testing

private func target(low: UInt128, high: UInt128 = 0) -> Target {
    Target(
        hex: String(high, radix: 16)
            + {
                let digits = String(low, radix: 16)
                return String(repeating: "0", count: 32 - digits.count) + digits
            }())!
}

private let maxWork = Chainwork(low: .max, high: .max)

@Suite("Chainwork")
struct ChainworkTests {
    @Suite struct FromTarget {
        /// Expected values computed with Python: 2²⁵⁶ // (target + 1).
        @Test(
            arguments: [
                (Int(0x1D00_FFFF), "100010001"),
                (0x1C00_FFFF, "10001000100"),
                (0x1B00_FFFF, "1000100010001"),
                (0x1D01_FFFE, "80008000"),
                (0x1D00_D86A, "12ed3afd2"),
                (0x1B04_04CB, "3fb3ab764c00"),
                (0x1F11_1111, "f00"),
                (0x1903_A30C, "4663bb9efdacfcf2"),
                (0x1234_5678, "4e42c9406c694408de2d51dec8c58"),
                (0x1703_4219, "4e9235f043634662e0cb"),
                (0x207F_FFFF, "2"),
                (0x2100_FFFF, "1"),
                (0x0101_0000, "8" + String(repeating: "0", count: 63)),
            ] as [(Int, String)])
        func knownValues(bits: Int, expectedHex: String) {
            let work = Target(compact: bits)!.work
            #expect(work.description == String(repeating: "0", count: 64 - expectedHex.count) + expectedHex)
        }

        @Test func extremes() {
            #expect(Target(hex: String(repeating: "f", count: 64))!.work == Chainwork(low: 1))
            #expect(Target(hex: "1")!.work == Chainwork(low: 0, high: 1 << 127))
        }

        /// For target 2ᵏ − 1 the work is exactly 2²⁵⁶⁻ᵏ, which exercises every shift in the division.
        @Test(arguments: 1...256)
        func powersOfTwo(k: Int) {
            let allOnes = UInt128.max
            let t =
                k >= 128
                ? target(low: allOnes, high: k == 256 ? allOnes : (1 << (k - 128)) - 1)
                : target(low: (1 << k) - 1)
            let expected =
                256 - k >= 128
                ? Chainwork(low: 0, high: 1 << (256 - k - 128))
                : Chainwork(low: 1 << (256 - k))
            #expect(t.work == expected)
        }

        /// 2²⁵⁶ / 3 and 2²⁵⁶ / 5 don't divide evenly and must round down.
        @Test func roundsDown() {
            let fives = UInt128("55555555555555555555555555555555", radix: 16)!
            let threes = UInt128("33333333333333333333333333333333", radix: 16)!
            #expect(target(low: 2).work == Chainwork(low: fives, high: fives))
            #expect(target(low: 4).work == Chainwork(low: threes, high: threes))
        }

        /// Checks `work == ⌊2²⁵⁶ / (target + 1)⌋` with independent 512-bit multiplication:
        /// work·(t+1) ≤ 2²⁵⁶ < (work+1)·(t+1).
        @Test func matchesReferenceDivision() {
            for t in randomTargets(500, seed: 40) {
                let work = limbs(t.work)
                let divisor = addOne(limbs(bytes(of: t.value)))
                #expect(compareToTwoTo256(multiply(work, divisor)) <= 0, "\(t)")
                #expect(compareToTwoTo256(multiply(addOne(work), divisor)) > 0, "\(t)")
            }
        }

        @Test func harderTargetsHaveMoreWork() {
            let targets = randomTargets(300, seed: 41).sorted()
            for (harder, easier) in zip(targets, targets.dropFirst()) {
                #expect(harder.work >= easier.work)
            }
        }
    }

    @Suite struct Arithmetic {
        @Test func zeroIsTheIdentity() {
            for t in randomTargets(100, seed: 42) {
                #expect(t.work + .zero == t.work)
                #expect(t.work - .zero == t.work)
                #expect(t.work - t.work == .zero)
            }
        }

        @Test func addsAndSubtractsWithCarries() {
            #expect(Chainwork(low: .max) + Chainwork(low: 1) == Chainwork(low: 0, high: 1))
            #expect(Chainwork(low: 0, high: 1) - Chainwork(low: 1) == Chainwork(low: .max))
            #expect(maxWork - maxWork == .zero)
            #expect(Chainwork(low: .max, high: .max - 1) + Chainwork(low: 1) == Chainwork(low: 0, high: .max))
        }

        @Test func algebraicLaws() {
            let values = randomTargets(300, seed: 43).map(\.work)
            for (a, (b, c)) in zip(values, zip(values.dropFirst(), values.dropFirst(2))) {
                #expect(a + b == b + a)
                #expect((a + b) + c == a + (b + c))
                #expect(a + b - b == a)
            }
        }

        @Test func overflowTraps() async {
            await #expect(processExitsWith: .failure) {
                _ = Chainwork(low: .max, high: .max) + Chainwork(low: 1)
            }
        }

        @Test func underflowTraps() async {
            await #expect(processExitsWith: .failure) {
                _ = Chainwork.zero - Chainwork(low: 1)
            }
        }

        /// Chainwork through mainnet block 32,255: 32,256 blocks at minimum difficulty.
        @Test func accumulatesAlongAChain() {
            let perBlock = Target.difficultyOne.work
            let total = (0..<32_256).reduce(Chainwork.zero) { sum, _ in sum + perBlock }
            #expect(total == Chainwork(low: 32_256 * 0x1_0001_0001))
            #expect((perBlock + perBlock).description.hasSuffix("200020002"))
        }
    }

    @Suite struct Comparison {
        @Test func highWordFirst() {
            #expect(Chainwork(low: .max, high: 0) < Chainwork(low: 0, high: 1))
            #expect(Chainwork(low: 1, high: 1) > Chainwork(low: 0, high: 1))
            #expect(Chainwork.zero < Chainwork(low: 1))
            #expect(!(maxWork < maxWork))
        }

        @Test func picksTheChainWithMoreWork() {
            let easy = (0..<10).reduce(Chainwork.zero) { sum, _ in sum + Target.difficultyOne.work }
            let hard = Target(compact: 0x1C00_FFFF)!.work // one block at 256x difficulty
            #expect(hard > easy)
        }
    }

    @Suite struct BinaryCoding {
        /// What swift-bitcoin's `DifficultyTarget` writes: eight `UInt32` limbs, least significant
        /// first, each little-endian.
        private func difficultyTargetEncoding(_ work: Chainwork) -> [UInt8] {
            let limbs32 = limbs(work).flatMap {
                [UInt32(truncatingIfNeeded: $0), UInt32(truncatingIfNeeded: $0 >> 32)]
            }
            return limbs32.flatMap { limb in (0..<4).map { UInt8(truncatingIfNeeded: limb >> (8 * $0)) } }
        }

        private func encoded(_ work: Chainwork) -> [UInt8] {
            BitcoinBaseTests.encoded(byteCount: Chainwork.encodedByteCount) { work.encode(into: &$0) }
        }

        @Test func genesisWork() {
            let work = Target.difficultyOne.work // 0x100010001
            #expect(encoded(work) == [0x01, 0x00, 0x01, 0x00, 0x01] + [UInt8](repeating: 0, count: 27))
        }

        @Test func extremes() throws {
            #expect(encoded(.zero) == [UInt8](repeating: 0, count: 32))
            let max = Chainwork(low: .max, high: .max)
            #expect(encoded(max) == [UInt8](repeating: 0xFF, count: 32))
            #expect(try Chainwork(parsing: encoded(max)) == max)
            let boundary = Chainwork(low: 0, high: 1) // 2^128: byte 16 is the first byte of `high`
            #expect(encoded(boundary) == [UInt8](repeating: 0, count: 16) + [0x01] + [UInt8](repeating: 0, count: 15))
        }

        /// Existing block-index records, written by `DifficultyTarget`, read back unchanged.
        @Test func matchesDifficultyTargetLayout() throws {
            for t in randomTargets(500, seed: 132) {
                let work = t.work
                let stored = difficultyTargetEncoding(work)
                #expect(encoded(work) == stored)
                #expect(try Chainwork(parsing: stored) == work)
                #expect(try Chainwork(parsing: Data(stored)) == work)
            }
        }

        @Test func parsesConsecutivelyAndLeavesTheRest() throws {
            let works = randomTargets(3, seed: 133).map(\.work)
            let input = works.flatMap(encoded) + [0xAA, 0xBB]
            let (parsed, remaining) = try input.withParserSpan { span in
                (try (0..<3).map { _ in try Chainwork(parsing: &span) }, span.count)
            }
            #expect(parsed == works)
            #expect(remaining == 2)
        }

        @Test(arguments: 0..<32)
        func throwsOnShortInput(count: Int) {
            #expect(throws: ParsingError.self) { try Chainwork(parsing: [UInt8](repeating: 0, count: count)) }
        }

        @Test func encodingTrapsWithoutRoom() async {
            await #expect(processExitsWith: .failure) {
                withTemporaryAllocation(byteCount: 31, alignment: 1) { Chainwork.zero.encode(into: &$0) }
            }
        }
    }

    @Suite struct HexAndBytes {
        /// `nMinimumChainWork` values as Bitcoin Core and swift-bitcoin's `ConsensusParams` write them.
        @Test(arguments: [
            "00000000000000000000000000000000000000000000034a4690fe592dc49c7c", // testnet4
            "00000000000000000000000000000000000000000000000000000b463ea0a4b8", // signet
            "0000000000000000000000000000000000000000000000000000000000000000", // regtest
        ])
        func minimumChainWork(hex: String) throws {
            let work = try #require(Chainwork(hex: hex))
            #expect(work.description == hex)
            #expect(Chainwork(bigEndianBytes: bytes(fromHex: hex)) == work)
            #expect(Chainwork(bigEndianBytes: Data(bytes(fromHex: hex))) == work)
        }

        @Test func zeroIsValid() {
            #expect(Chainwork(hex: "0") == .zero)
            #expect(Chainwork(bigEndianBytes: [UInt8](repeating: 0, count: 32)) == .zero)
        }

        /// Short hex is zero-extended on the left; a prefix and either case are accepted.
        @Test func acceptsCoreStyleHex() {
            let genesisWork = Target.difficultyOne.work
            #expect(Chainwork(hex: "100010001") == genesisWork)
            #expect(Chainwork(hex: "0x100010001") == genesisWork)
            #expect(Chainwork(hex: String(repeating: "0", count: 55) + "100010001") == genesisWork)
            #expect(Chainwork(hex: "ABCDEF") == Chainwork(hex: "abcdef"))
            #expect(Chainwork(hex: String(repeating: "f", count: 64)) == Chainwork(low: .max, high: .max))
        }

        /// The word boundary: byte 16 of the big-endian form is the low word's top byte.
        @Test func wordBoundary() {
            var bytes = [UInt8](repeating: 0, count: 32)
            bytes[15] = 0x01
            bytes[16] = 0x80
            #expect(Chainwork(bigEndianBytes: bytes) == Chainwork(low: 0x80 << 120, high: 1))
        }

        @Test func roundTripsThroughDescription() {
            for t in randomTargets(500, seed: 131) {
                let work = t.work
                #expect(Chainwork(hex: work.description) == work)
                #expect(Chainwork(bigEndianBytes: bytes(fromHex: work.description)) == work)
            }
        }

        /// Zero is valid but must be written: no digits at all is rejected.
        @Test(arguments: ["", "0x", "0X", String(repeating: "f", count: 65), "-1", "+1", " 1", "1 ", "0xg", "0x0x1"])
        func rejectsMalformedHex(text: String) {
            #expect(Chainwork(hex: text) == nil)
        }

        @Test(arguments: [0, 1, 31, 33, 64])
        func rejectsWrongLength(count: Int) {
            #expect(Chainwork(bigEndianBytes: [UInt8](repeating: 0x01, count: count)) == nil)
        }

        /// The `InlineArray` overload can't fail, and agrees with the `Collection` one.
        @Test func inlineArrayMatchesCollection() {
            for t in randomTargets(500, seed: 135) {
                let work = t.work
                let bigEndian = bytes(fromHex: work.description)
                let fromInline: Chainwork = Chainwork(bigEndianBytes: InlineArray<32, UInt8> { bigEndian[$0] })
                #expect(fromInline == work)
            }
            #expect(Chainwork(bigEndianBytes: InlineArray<32, UInt8>(repeating: 0)) == .zero)
            #expect(
                Chainwork(bigEndianBytes: InlineArray<32, UInt8>(repeating: 0xFF)) == Chainwork(low: .max, high: .max))
        }

        /// Byte 15 is the high word's least significant byte, byte 16 the low word's most significant.
        @Test func inlineArrayWordBoundary() {
            var bytes = InlineArray<32, UInt8>(repeating: 0)
            bytes[15] = 0x01
            bytes[16] = 0x80
            #expect(Chainwork(bigEndianBytes: bytes) == Chainwork(low: 0x80 << 120, high: 1))
        }

        /// testnet4's `nMinimumChainWork` as an inline literal, and an untyped literal of the same.
        @Test func literals() {
            let testnet4: InlineArray<32, UInt8> = [
                0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00,
                0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x03, 0x4A, 0x46, 0x90, 0xFE, 0x59, 0x2D, 0xC4, 0x9C, 0x7C,
            ]
            let expected = Chainwork(hex: "34a4690fe592dc49c7c")
            #expect(Chainwork(bigEndianBytes: testnet4) == expected)
            let untyped = Chainwork(bigEndianBytes: [
                0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00,
                0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x03, 0x4A, 0x46, 0x90, 0xFE, 0x59, 0x2D, 0xC4, 0x9C, 0x7C,
            ])
            #expect(untyped == expected)
        }
    }

    @Suite struct Description {
        @Test func isSixtyFourHexDigits() {
            #expect(Chainwork.zero.description == String(repeating: "0", count: 64))
            #expect(maxWork.description == String(repeating: "f", count: 64))
            #expect(
                Chainwork(low: 0, high: 1).description == String(repeating: "0", count: 31) + "1"
                    + String(repeating: "0", count: 32))
            for t in randomTargets(100, seed: 44) {
                #expect(t.work.description.count == 64)
            }
        }
    }
}
