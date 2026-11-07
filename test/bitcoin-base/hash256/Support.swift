import Crypto
import Foundation
import Testing

@testable import BitcoinBase

// MARK: - Deterministic randomness

/// SplitMix64, so property tests see the same values on every run.
struct SplitMix64: RandomNumberGenerator {
    private var state: UInt64

    init(seed: UInt64) {
        state = seed
    }

    mutating func next() -> UInt64 {
        state &+= 0x9E37_79B9_7F4A_7C15
        var z = state
        z = (z ^ (z >> 30)) &* 0xBF58_476D_1CE4_E5B9
        z = (z ^ (z >> 27)) &* 0x94D0_49BB_1331_11EB
        return z ^ (z >> 31)
    }
}

func randomBytes(_ rng: inout SplitMix64) -> [UInt8] {
    (0..<32).map { _ in UInt8.random(in: .min ... .max, using: &rng) }
}

func randomHashes(_ count: Int, seed: UInt64) -> [Hash256] {
    var rng = SplitMix64(seed: seed)
    return (0..<count).map { _ in hash(randomBytes(&rng)) }
}

/// Random non-zero targets, with a random number of leading zero bytes so every size is covered.
func randomTargets(_ count: Int, seed: UInt64) -> [Target] {
    var rng = SplitMix64(seed: seed)
    return (0..<count).map { _ in
        var bytes = randomBytes(&rng)
        let significant = Int.random(in: 1...32, using: &rng)
        for i in significant..<32 { bytes[i] = 0 }
        bytes[significant - 1] |= 1
        return Target(hash(bytes))!
    }
}

// MARK: - Bytes and hex

func bytes(fromHex hex: String) -> [UInt8] {
    precondition(hex.count.isMultiple(of: 2))
    return stride(from: 0, to: hex.count, by: 2).map { i in
        let start = hex.index(hex.startIndex, offsetBy: i)
        return UInt8(hex[start..<hex.index(start, offsetBy: 2)], radix: 16)!
    }
}

func hex(_ bytes: some Sequence<UInt8>) -> String {
    bytes.map { $0 < 0x10 ? "0" + String($0, radix: 16) : String($0, radix: 16) }.joined()
}

func hash(_ bytes: [UInt8]) -> Hash256 {
    Hash256(bytes: bytes.span)!
}

func bytes(of hash: Hash256) -> [UInt8] {
    hash.bytes.indices.map { hash.bytes[$0] }
}

func doubleSHA256(_ bytes: [UInt8]) -> Hash256 {
    Hash256(SHA256.hash(data: Data(SHA256.hash(data: bytes))))
}

/// Runs `body` against a fresh `OutputRawSpan` of `byteCount` bytes and returns what it wrote.
func encoded(byteCount: Int, _ body: (inout OutputRawSpan) -> Void) -> [UInt8] {
    withTemporaryAllocation(byteCount: byteCount, alignment: 1) { output in
        body(&output)
        return [UInt8](output.bytes)
    }
}

// MARK: - Byte patterns

/// Edge-case byte layouts, named for readable test output.
struct BytePattern: Sendable, CustomTestStringConvertible {
    let name: String
    let bytes: [UInt8]

    var testDescription: String { name }

    init(_ name: String, _ make: (inout [UInt8]) -> Void) {
        var bytes = [UInt8](repeating: 0, count: 32)
        make(&bytes)
        self.name = name
        self.bytes = bytes
    }

    static let all: [BytePattern] = [
        BytePattern("zero") { _ in },
        BytePattern("all 0xff") { $0 = [UInt8](repeating: 0xFF, count: 32) },
        BytePattern("ascending") { $0 = Array(0..<32) },
        BytePattern("descending") { $0 = Array((0..<32).reversed()) },
        BytePattern("first byte only") { $0[0] = 0x01 },
        BytePattern("last byte only") { $0[31] = 0x01 },
        BytePattern("top bit only") { $0[31] = 0x80 },
        BytePattern("low word max") { for i in 0..<16 { $0[i] = 0xFF } },
        BytePattern("high word max") { for i in 16..<32 { $0[i] = 0xFF } },
        BytePattern("word boundary") {
            $0[15] = 0xFF
            $0[16] = 0x01
        },
        BytePattern("alternating") { for i in 0..<32 { $0[i] = i.isMultiple(of: 2) ? 0xAA : 0x55 } },
        BytePattern("single-digit bytes") { $0 = [UInt8](repeating: 0x0A, count: 32) },
    ]

    /// Every pattern except zero, which isn't a valid target.
    static let nonZero = all.filter { $0.bytes.contains { $0 != 0 } }
}

/// The 256 hashes with exactly one bit set, bit 0 being the least significant.
func singleBit(_ bit: Int) -> [UInt8] {
    var bytes = [UInt8](repeating: 0, count: 32)
    bytes[bit / 8] = 1 << (bit % 8)
    return bytes
}

// MARK: - Reference models
// Written independently of the library, on plain byte arrays, to check it against.

/// `a < b` reading both as 256-bit little-endian integers.
func referenceLess(_ a: [UInt8], _ b: [UInt8]) -> Bool {
    a.reversed().lexicographicallyPrecedes(b.reversed())
}

/// What a compact encoding keeps: the 3 most significant bytes, or 2 when the top one has its
/// high bit set (it would read as the sign).
func referenceCompactTruncation(_ value: [UInt8]) -> [UInt8] {
    guard let top = value.lastIndex(where: { $0 != 0 }) else { return value }
    let kept = value[top] & 0x80 != 0 ? 2 : 3
    var result = value
    for i in 0..<max(0, top - kept + 1) { result[i] = 0 }
    return result
}

/// `value + 1` as a 256-bit little-endian integer, or `nil` if it overflows.
func addingOne(_ value: [UInt8]) -> [UInt8]? {
    var result = value
    for i in 0..<32 {
        let (sum, overflow) = result[i].addingReportingOverflow(1)
        result[i] = sum
        if !overflow { return result }
    }
    return nil
}

/// `value - 1` as a 256-bit little-endian integer; wraps zero to the maximum.
func subtractingOne(_ value: [UInt8]) -> [UInt8] {
    var result = value
    for i in 0..<32 {
        let (difference, borrow) = result[i].subtractingReportingOverflow(1)
        result[i] = difference
        if !borrow { break }
    }
    return result
}

/// Limbs of a 256-bit little-endian value, least significant first.
func limbs(_ bytes: [UInt8]) -> [UInt64] {
    (0..<4).map { limb in (0..<8).reduce(0) { $0 | UInt64(bytes[limb * 8 + $1]) << (8 * $1) } }
}

func limbs(_ work: Chainwork) -> [UInt64] {
    [
        UInt64(truncatingIfNeeded: work.low), UInt64(truncatingIfNeeded: work.low >> 64),
        UInt64(truncatingIfNeeded: work.high), UInt64(truncatingIfNeeded: work.high >> 64),
    ]
}

/// Schoolbook multiplication of little-endian limb arrays.
func multiply(_ a: [UInt64], _ b: [UInt64]) -> [UInt64] {
    var result = [UInt64](repeating: 0, count: a.count + b.count)
    for i in a.indices {
        var carry: UInt64 = 0
        for j in b.indices {
            let (high, low) = a[i].multipliedFullWidth(by: b[j])
            let (sum1, o1) = result[i + j].addingReportingOverflow(low)
            let (sum2, o2) = sum1.addingReportingOverflow(carry)
            result[i + j] = sum2
            carry = high &+ (o1 ? 1 : 0) &+ (o2 ? 1 : 0)
        }
        result[i + b.count] = carry
    }
    return result
}

func addOne(_ a: [UInt64]) -> [UInt64] {
    var result = a + [0]
    var i = 0
    while true {
        let (sum, overflow) = result[i].addingReportingOverflow(1)
        result[i] = sum
        if !overflow { return result }
        i += 1
    }
}

/// Short division of a little-endian limb array by a 64-bit divisor (remainder discarded).
func divide(_ a: [UInt64], by divisor: UInt64) -> [UInt64] {
    var result = a
    var remainder: UInt64 = 0
    for i in result.indices.reversed() {
        (result[i], remainder) = divisor.dividingFullWidth((high: remainder, low: result[i]))
    }
    return result
}

/// Compares a little-endian limb array with 2²⁵⁶.
func compareToTwoTo256(_ a: [UInt64]) -> Int {
    let above = a.count > 5 && a[5...].contains { $0 != 0 }
    if above { return 1 }
    let limb4 = a.count > 4 ? a[4] : 0
    if limb4 > 1 { return 1 }
    if limb4 == 1 { return a[0..<4].allSatisfy { $0 == 0 } ? 0 : 1 }
    return -1
}

// MARK: - Fixtures

enum Fixtures {
    static let mainnetPowLimit = Target(hex: "00000000ffffffffffffffffffffffffffffffffffffffffffffffffffffffff")!
    static let regtestPowLimit = Target(hex: "7fffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffff")!

    static let genesisHeader = bytes(
        fromHex:
            "0100000000000000000000000000000000000000000000000000000000000000"
            + "000000003ba3edfd7a7b12b27ac72c3e67768f617fc81bc3888a51323a9fb8aa"
            + "4b1e5e4a29ab5f49ffff001d1dac2b7c")
    static let genesisHash = "000000000019d6689c085ae165831e934ff763ae46a2a6c172b3f1b60a8ce26f"
    static let genesisMerkleRoot = "4a5e1e4baab89f3a32518a88c31bc87f618f76673e2cc77ab2127b7afdeda33b"

    static let block1Header = bytes(
        fromHex:
            "010000006fe28c0ab6f1b372c1a6a246ae63f74f931e8365e15a089c68d61900"
            + "00000000982051fd1e4ba744bbbe680e1fee14677ba1a3c3540bf7b1cdb606e8"
            + "57233e0e61bc6649ffff001d01e36299")
    static let block1Hash = "00000000839a8e6886ab5951d76f411475428afc90947ee320161bbf18eb6048"
    static let block1MerkleRoot = "0e3e2357e806b6cdb1f70b54c3a3a17b6714ee1f0e68bebb44a74b1efd512098"

    /// Malformed 64-digit hex strings; each must be rejected by fixed-width hex parsers.
    static let malformedDisplayHex: [String] = {
        let valid = genesisHash
        let short = String(valid.dropLast())
        return [
            "", "0x", "0X", short, valid + "0", "0x" + short, "0x" + valid + "0",
            "+" + short, "-" + short, " " + short, short + " ",
            String(valid.prefix(32)) + " " + String(valid.suffix(31)),
            "g" + short, short + "g", "\u{FF10}" + short, "0x0x" + String(valid.dropLast(2)),
        ]
    }()
}
