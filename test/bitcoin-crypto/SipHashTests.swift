import Crypto
import Foundation
import Testing

@testable import BitcoinCrypto

// MARK: - Helpers

/// Key bytes `00 01 … 0f` as the two little-endian words the reference code uses.
private let referenceK0: UInt64 = 0x0706_0504_0302_0100
private let referenceK1: UInt64 = 0x0f0e_0d0c_0b0a_0908

private func siphash(_ message: [UInt8], key: [UInt8] = SipHashReferenceVectors.referenceKey) -> SipHash.Digest? {
    guard var hasher = SipHash(key: key.span) else { return nil }
    hasher.update(bytes: message.span)
    return hasher.finalize()
}

private func makeDigest(from bytes: [UInt8]) -> SipHash.Digest? {
    SipHash.Digest(bytes: bytes.span)
}

private func makeHasher(key: [UInt8]) -> SipHash? {
    SipHash(key: key.span)
}

private func hasher(key: [UInt8]) -> SipHash {
    makeHasher(key: key)!
}

// MARK: - Known answer tests

@Suite("SipHash Known answers")
struct SipHashKnownAnswerTests {

    @Test("Paper test vector: 15-byte message, key 00…0f → a129ca6149be45e5")
    func paperVector() {
        let message = Array(0..<15) as [UInt8]
        #expect(siphash(message)?.value == 0xa129_ca61_49be_45e5)
    }

    @Test("Empty message → 726fdb47dd0e0e31")
    func emptyMessage() {
        #expect(siphash([])?.value == 0x726f_db47_dd0e_0e31)
    }

    /// Official vectors (https://github.com/veorq/SipHash, vectors.h): messages `00…(n-1)` for n in 0..<64.
    @Test("Official SipHash-2-4 vectors, n = 0…63", arguments: 0..<64)
    func officialVectors(n: Int) {
        let message = (0..<n).map { UInt8($0) }
        #expect(siphash(message)?.hexString == SipHashReferenceVectors.official[n])
    }

    /// 55 messages/keys hashed by OpenSSL (see `SipHashReferenceVectors.swift`). Covers every word-boundary
    /// length (7/8/9, 15/16/17, …) and multi-word inputs under different keys.
    @Test("Differential vectors against OpenSSL", arguments: SipHashReferenceVectors.differential)
    func differentialVectors(vector: (seed: Int, length: Int, hex: String)) {
        let message = SipHashReferenceVectors.message(length: vector.length)
        let key = SipHashReferenceVectors.key(seed: vector.seed)
        #expect(siphash(message, key: key)?.hexString == vector.hex)
    }

    @Test("Key words: k0/k1 are the little-endian reading of the key bytes")
    func keyWords() {
        let message = Array(0..<15) as [UInt8]
        var viaWords = SipHash(k0: referenceK0, k1: referenceK1)
        viaWords.update(bytes: message.span)
        #expect(viaWords.finalize().value == 0xa129_ca61_49be_45e5)
    }

    @Test("swift-bitcoin's key convention (big-endian literals byte-swapped) gives the same result")
    func swiftBitcoinKeyConvention() {
        // Their tests pass `UInt64(0x0001_0203_0405_0607).bigEndian`, which on a little-endian
        // machine is exactly `referenceK0`.
        let k0 = UInt64(0x0001_0203_0405_0607).bigEndian
        let k1 = UInt64(0x0809_0a0b_0c0d_0e0f).bigEndian
        #expect(k0 == referenceK0 && k1 == referenceK1)
    }

    @Test("One-shot static hash(bytes:k0:k1:)")
    func oneShot() {
        let message = Array(0..<15) as [UInt8]
        let digest = SipHash.hash(bytes: message.span, k0: referenceK0, k1: referenceK1)
        #expect(digest.value == 0xa129_ca61_49be_45e5)
    }

    @Test("BIP152-style 6-byte truncation")
    func shortID() {
        let message = Array(0..<15) as [UInt8]
        let digest = SipHash.hash(bytes: message.span, k0: referenceK0, k1: referenceK1)
        let expected: UInt64 = 0xa129_ca61_49be_45e5 & 0xffff_ffff_ffff
        #expect((digest.value << 16) >> 16 == expected)
    }
}

// MARK: - Incremental hashing

@Suite("SipHash Incremental hashing")
struct SipHashIncrementalTests {

    @Test("Every two-way split of every length 0…80 matches the one-shot result")
    func allSplits() {
        for length in 0...80 {
            let message = SipHashReferenceVectors.message(length: length)
            let expected = siphash(message)
            for split in 0...length {
                var hasher = hasher(key: SipHashReferenceVectors.referenceKey)
                hasher.update(bytes: message.span.extracting(0..<split))
                hasher.update(bytes: message.span.extracting(split..<length))
                #expect(hasher.finalize() == expected, "length \(length), split \(split)")
            }
        }
    }

    @Test("Every three-way split at word boundaries and neighbours")
    func threeWaySplits() {
        let message = SipHashReferenceVectors.message(length: 40)
        let expected = siphash(message)
        for a in 0...40 {
            for b in a...40 {
                var hasher = hasher(key: SipHashReferenceVectors.referenceKey)
                hasher.update(bytes: message.span.extracting(0..<a))
                hasher.update(bytes: message.span.extracting(a..<b))
                hasher.update(bytes: message.span.extracting(b..<40))
                #expect(hasher.finalize() == expected, "splits \(a), \(b)")
            }
        }
    }

    @Test("Byte-at-a-time matches one-shot", arguments: [0, 1, 7, 8, 9, 15, 16, 17, 63, 64, 65, 1000])
    func byteByByte(length: Int) {
        let message = SipHashReferenceVectors.message(length: length)
        var hasher = hasher(key: SipHashReferenceVectors.referenceKey)
        for byte in message { hasher.update(bytes: [byte].span) }
        #expect(hasher.finalize() == siphash(message))
    }

    @Test("Pseudo-random chunking matches one-shot")
    func randomChunks() {
        var seed: UInt64 = 0x9e37_79b9_7f4a_7c15
        func next() -> Int {
            seed = seed &* 6_364_136_223_846_793_005 &+ 1_442_695_040_888_963_407
            return Int(truncatingIfNeeded: seed >> 33)
        }
        for _ in 0..<200 {
            let length = next() % 2_000
            let message = (0..<length).map { _ in UInt8(truncatingIfNeeded: next()) }
            var hasher = hasher(key: SipHashReferenceVectors.referenceKey)
            var offset = 0
            while offset < length {
                let size = min(next() % 40, length - offset)
                hasher.update(bytes: message.span.extracting(offset..<(offset + size)))
                offset += size
            }
            #expect(hasher.finalize() == siphash(message))
        }
    }

    @Test("Messages longer than 255 bytes: only the low byte of the length is mixed in")
    func lengthWraps() {
        for length in [255, 256, 257, 511, 512, 513, 4_097] {
            let message = SipHashReferenceVectors.message(length: length)
            // 4097 is in the OpenSSL fixture; the others are cross-checked via splitting + the fixture lengths.
            var whole = hasher(key: SipHashReferenceVectors.referenceKey)
            whole.update(bytes: message.span)
            var split = hasher(key: SipHashReferenceVectors.referenceKey)
            split.update(bytes: message.span.extracting(0..<100))
            split.update(bytes: message.span.extracting(100..<length))
            #expect(whole.finalize() == split.finalize())
        }
        let long = SipHashReferenceVectors.differential.last { $0.length == 4_097 }
        #expect(long != nil)
    }

    @Test("Empty updates are no-ops")
    func emptyUpdates() {
        let message = Array(0..<15) as [UInt8]
        var hasher = hasher(key: SipHashReferenceVectors.referenceKey)
        hasher.update(bytes: [UInt8]().span)
        hasher.update(bytes: message.span)
        hasher.update(bytes: [UInt8]().span)
        #expect(hasher.finalize().value == 0xa129_ca61_49be_45e5)
    }

    @Test("finalize() is non-destructive and the hasher can keep absorbing")
    func finalizeIsNonDestructive() {
        let message = Array(0..<15) as [UInt8]
        var hasher = hasher(key: SipHashReferenceVectors.referenceKey)
        hasher.update(bytes: message.span.extracting(0..<5))
        let first = hasher.finalize()
        #expect(hasher.finalize() == first)
        #expect(first == siphash(Array(message[0..<5])))

        hasher.update(bytes: message.span.extracting(5..<15))
        #expect(hasher.finalize().value == 0xa129_ca61_49be_45e5)
    }

    @Test("Hasher is a value type: copies are independent")
    func valueSemantics() {
        var original = hasher(key: SipHashReferenceVectors.referenceKey)
        original.update(bytes: [0, 1].span)
        var copy = original
        copy.update(bytes: [2].span)
        original.update(bytes: [9].span)
        #expect(copy.finalize() == siphash([0, 1, 2]))
        #expect(original.finalize() == siphash([0, 1, 9]))
    }

    @Test("Different keys give different digests")
    func keySensitivity() {
        let message = SipHashReferenceVectors.message(length: 20)
        #expect(siphash(message, key: SipHashReferenceVectors.key(seed: 1)) != siphash(message, key: SipHashReferenceVectors.key(seed: 2)))
    }
}

// MARK: - Keys

@Suite("Keys")
struct KeyTests {

    @Test("init?(key:) accepts exactly 16 bytes")
    func keyLength() {
        #expect(makeHasher(key: [UInt8](repeating: 0, count: 16)) != nil)
    }

    @Test("init?(key:) rejects other lengths", arguments: [0, 1, 8, 15, 17, 32])
    func wrongKeyLength(count: Int) {
        #expect(makeHasher(key: [UInt8](repeating: 0, count: count)) == nil)
    }

    @Test("init?(key:) and init(k0:k1:) agree")
    func keyInitializersAgree() {
        let message = SipHashReferenceVectors.message(length: 33)
        var viaKey = hasher(key: SipHashReferenceVectors.referenceKey)
        viaKey.update(bytes: message.span)
        var viaWords = SipHash(k0: referenceK0, k1: referenceK1)
        viaWords.update(bytes: message.span)
        #expect(viaKey.finalize() == viaWords.finalize())
    }

    @Test("Random-key init() produces independent keys")
    func randomKeys() {
        let message = SipHashReferenceVectors.message(length: 32)
        var a = SipHash()
        var b = SipHash()
        a.update(bytes: message.span)
        b.update(bytes: message.span)
        // 2⁻⁶⁴ chance of a false failure.
        #expect(a.finalize() != b.finalize())
    }
}

// MARK: - Digest

@Suite("SipHash Digest")
struct SipHashDigestTests {

    let digest = SipHash.Digest(value: 0xa129_ca61_49be_45e5)

    @Test("Sizes and constants")
    func sizes() {
        #expect(SipHash.Digest.byteCount == 8)
        #expect(SipHash.blockByteCount == 8)
        #expect(SipHash.c == 2)
        #expect(SipHash.d == 4)
    }

    @Test("Bytes are little-endian")
    func bytes() {
        #expect(Array(digest) == [0xe5, 0x45, 0xbe, 0x49, 0x61, 0xca, 0x29, 0xa1])
    }

    @Test("Hex and description")
    func formatting() {
        #expect(digest.hexString == "e545be4961ca29a1")
        #expect(digest.description == "SipHash digest: e545be4961ca29a1")
    }

    @Test("withUnsafeBytes (ContiguousBytes) exposes the same little-endian bytes")
    func withUnsafeBytes() {
        let viaPointer = unsafe digest.withUnsafeBytes { unsafe Array($0) }
        #expect(viaPointer == Array(digest))
    }

    @Test("Round-trips through init?(bytes:)")
    func roundTrip() throws {
        let bytes = Array(digest)
        let rebuilt = try #require(makeDigest(from: bytes))
        #expect(rebuilt == digest)
        #expect(rebuilt.value == digest.value)
    }

    @Test("init?(bytes:) rejects wrong lengths", arguments: [0, 1, 7, 9, 16])
    func wrongLength(count: Int) {
        #expect(makeDigest(from: [UInt8](repeating: 0, count: count)) == nil)
    }

    @Test("Equality and hashing")
    func equalityAndHashing() {
        let other = SipHash.Digest(value: 1)
        #expect(digest == SipHash.Digest(value: 0xa129_ca61_49be_45e5))
        #expect(digest != other)
        #expect(Set([digest, digest, other]).count == 2)
    }
}

// MARK: - swift-crypto / CryptoKit protocol conformance

@Suite("HashFunction conformance")
struct SipHashConformanceTests {

    private func hashGeneric<H: HashFunction>(_ hasher: H, _ message: [UInt8]) -> [UInt8] {
        var hasher = hasher
        hasher.update(data: message)
        return Array(hasher.finalize())
    }

    @Test("Usable generically as a HashFunction")
    func generic() {
        let result = hashGeneric(SipHash(k0: referenceK0, k1: referenceK1), Array(0..<15) as [UInt8])
        #expect(result == [0xe5, 0x45, 0xbe, 0x49, 0x61, 0xca, 0x29, 0xa1])
    }

    @Test("update(data:) with Data")
    func updateData() {
        var hasher = SipHash(k0: referenceK0, k1: referenceK1)
        hasher.update(data: Data(Array(0..<15) as [UInt8]))
        #expect(hasher.finalize().value == 0xa129_ca61_49be_45e5)
    }

    @Test("update(bufferPointer:) agrees with the Span API")
    func bufferPointer() {
        let message = SipHashReferenceVectors.message(length: 1_000)
        var viaPointer = hasher(key: SipHashReferenceVectors.referenceKey)
        message.withUnsafeBytes { unsafe viaPointer.update(bufferPointer: $0) }
        #expect(viaPointer.finalize() == siphash(message))
    }

    @Test("RawSpan overload inherited from Crypto")
    func rawSpan() {
        let message = SipHashReferenceVectors.message(length: 1_000)
        var hasher = hasher(key: SipHashReferenceVectors.referenceKey)
        hasher.update(bytes: message.span.bytes.extracting(0..<333))
        hasher.update(bytes: message.span.bytes.extracting(333..<1_000))
        #expect(hasher.finalize() == siphash(message))
    }

    @Test("Data's span feeds the Span API")
    func dataSpan() {
        let data = Data(SipHashReferenceVectors.message(length: 777))
        let viaSpan = SipHash.hash(bytes: data.span, k0: referenceK0, k1: referenceK1)
        #expect(viaSpan == siphash(SipHashReferenceVectors.message(length: 777)))
    }
}
