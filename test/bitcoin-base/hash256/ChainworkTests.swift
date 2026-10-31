import BitcoinBase
import Testing

private func target(low: UInt128, high: UInt128 = 0) -> Target {
    Target(hex: String(high, radix: 16) + {
        let digits = String(low, radix: 16)
        return String(repeating: "0", count: 32 - digits.count) + digits
    }())!
}

private let maxWork = Chainwork(low: .max, high: .max)

@Suite("Chainwork")
struct ChainworkTests {
    @Suite struct FromTarget {
        /// Expected values computed with Python: 2²⁵⁶ // (target + 1).
        @Test(arguments: [
            (UInt32(0x1D00_FFFF), "100010001"),
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
        ] as [(UInt32, String)])
        func knownValues(bits: UInt32, expectedHex: String) {
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
            let t = k >= 128
                ? target(low: allOnes, high: k == 256 ? allOnes : (1 << (k - 128)) - 1)
                : target(low: (1 << k) - 1)
            let expected = 256 - k >= 128
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
            let hard = Target(compact: 0x1C00_FFFF)!.work  // one block at 256x difficulty
            #expect(hard > easy)
        }
    }

    @Suite struct Description {
        @Test func isSixtyFourHexDigits() {
            #expect(Chainwork.zero.description == String(repeating: "0", count: 64))
            #expect(maxWork.description == String(repeating: "f", count: 64))
            #expect(Chainwork(low: 0, high: 1).description == String(repeating: "0", count: 31) + "1" + String(repeating: "0", count: 32))
            for t in randomTargets(100, seed: 44) {
                #expect(t.work.description.count == 64)
            }
        }
    }
}
