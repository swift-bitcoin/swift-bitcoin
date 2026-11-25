import Crypto
import Foundation
import Testing

@testable import BitcoinCrypto

// MARK: - Helpers

private func ripemd160(_ bytes: [UInt8]) -> String {
    RIPEMD160.hash(bytes: bytes.span).hexString
}

private func ripemd160(_ string: String) -> String {
    ripemd160(Array(string.utf8))
}

private func digest(from bytes: [UInt8]) -> RIPEMD160.Digest? {
    RIPEMD160.Digest(bytes: bytes.span)
}

// MARK: - Known answer tests

@Suite("RIPEMD-160 Known answers")
struct RIPEMD160KnownAnswerTests {

    /// Official vectors from the algorithm authors:
    /// https://homes.esat.kuleuven.be/~bosselae/ripemd160.html
    @Test(
        "Official RIPEMD-160 test vectors",
        arguments: [
            ("", "9c1185a5c5e9fc54612808977ee8f548b2258d31"),
            ("a", "0bdc9d2d256b3ee9daae347be6f4dc835a467ffe"),
            ("abc", "8eb208f7e05d987a9b044a8e98c6b087f15a0bfc"),
            ("message digest", "5d0689ef49d2fae572b881b123a85ffa21595f36"),
            ("abcdefghijklmnopqrstuvwxyz", "f71c27109c692c1b56bbdceb5b9d2865b3708dbc"),
            (
                "abcdbcdecdefdefgefghfghighijhijkijkljklmklmnlmnomnopnopq",
                "12a053384a9c0c88e405a06c27dcf49ada62eb2b"
            ),
            (
                "ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789",
                "b0e20b6e3116640286ed3a87a5713079b21f5189"
            ),
        ])
    func officialVectors(message: String, expected: String) {
        #expect(ripemd160(message) == expected)
    }

    @Test("8 × \"1234567890\"")
    func eightTimesDigits() {
        let message = String(repeating: "1234567890", count: 8)
        #expect(ripemd160(message) == "9b752e45573d4b39f4dbd3323cab82bf63326bfb")
    }

    @Test("One million 'a' (official vector), fed in odd-sized chunks")
    func millionA() {
        let chunk = [UInt8](repeating: UInt8(ascii: "a"), count: 1_000)
        var hasher = RIPEMD160()
        for _ in 0..<1_000 { hasher.update(bytes: chunk.span) }
        #expect(hasher.finalize().hexString == "52783243c1697bdbe16d37f97f68f08325dc1528")

        // 1_000_000 = 7 × 142_857 + 1: exercises a non-block-aligned stride.
        var odd = RIPEMD160()
        let stride = [UInt8](repeating: UInt8(ascii: "a"), count: 7)
        for _ in 0..<142_857 { odd.update(bytes: stride.span) }
        odd.update(bytes: [UInt8(ascii: "a")].span)
        #expect(odd.finalize().hexString == "52783243c1697bdbe16d37f97f68f08325dc1528")
    }

    @Test("Wikipedia vectors")
    func wikipedia() {
        #expect(
            ripemd160("The quick brown fox jumps over the lazy dog")
                == "37f332f68db77bd9d7edd4969571ad671cf9dd3b")
        #expect(
            ripemd160("The quick brown fox jumps over the lazy cog")
                == "132072df690933835eb8b6ad0b77e7b6f14acad7")
    }

    @Test("Bitcoin HASH160 = RIPEMD160(SHA256(x)) of a compressed public key")
    func hash160() {
        // Generator point G, compressed. Well-known address hash 751e76e8199196d454941c45d1b3a323f1433bd6.
        let pubkey: [UInt8] = [
            0x02, 0x79, 0xbe, 0x66, 0x7e, 0xf9, 0xdc, 0xbb, 0xac, 0x55, 0xa0, 0x62, 0x95, 0xce, 0x87, 0x0b,
            0x07, 0x02, 0x9b, 0xfc, 0xdb, 0x2d, 0xce, 0x28, 0xd9, 0x59, 0xf2, 0x81, 0x5b, 0x16, 0xf8, 0x17, 0x98,
        ]
        let sha = Array(SHA256.hash(data: pubkey))
        #expect(ripemd160(sha) == "751e76e8199196d454941c45d1b3a323f1433bd6")
    }

    /// 309 messages of varying length hashed by OpenSSL (see `ReferenceVectors.swift`).
    /// Covers every padding boundary (55/56/57, 63/64/65, 119/120/121, …) and multi-block inputs.
    @Test("Differential vectors against OpenSSL", arguments: RIPEMD160ReferenceVectors.digests)
    func referenceVectors(vector: (length: Int, hex: String)) {
        let message = RIPEMD160ReferenceVectors.message(length: vector.length)
        #expect(ripemd160(message) == vector.hex)
    }
}

// MARK: - Incremental hashing

@Suite("RIPEMD-160 Incremental hashing")
struct RIPEMD160IncrementalTests {

    @Test("Every two-way split of every length 0…200 matches the one-shot result")
    func allSplits() {
        for length in 0...200 {
            let message = RIPEMD160ReferenceVectors.message(length: length)
            let expected = RIPEMD160.hash(bytes: message.span)
            for split in 0...length {
                var hasher = RIPEMD160()
                hasher.update(bytes: message.span.extracting(0..<split))
                hasher.update(bytes: message.span.extracting(split..<length))
                #expect(hasher.finalize() == expected, "length \(length), split \(split)")
            }
        }
    }

    @Test("Byte-at-a-time matches one-shot", arguments: [0, 1, 55, 56, 63, 64, 65, 127, 128, 129, 1000])
    func byteByByte(length: Int) {
        let message = RIPEMD160ReferenceVectors.message(length: length)
        var hasher = RIPEMD160()
        for byte in message { hasher.update(bytes: [byte].span) }
        #expect(hasher.finalize() == RIPEMD160.hash(bytes: message.span))
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
            var hasher = RIPEMD160()
            var offset = 0
            while offset < length {
                let size = min(next() % 150, length - offset)
                hasher.update(bytes: message.span.extracting(offset..<(offset + size)))
                offset += size
            }
            #expect(hasher.finalize() == RIPEMD160.hash(bytes: message.span))
        }
    }

    @Test("Empty updates are no-ops")
    func emptyUpdates() {
        var hasher = RIPEMD160()
        hasher.update(bytes: [UInt8]().span)
        hasher.update(bytes: Array("abc".utf8).span)
        hasher.update(bytes: [UInt8]().span)
        #expect(hasher.finalize().hexString == "8eb208f7e05d987a9b044a8e98c6b087f15a0bfc")
    }

    @Test("finalize() is non-destructive and the hasher can keep absorbing")
    func finalizeIsNonDestructive() {
        var hasher = RIPEMD160()
        hasher.update(bytes: Array("a".utf8).span)
        let first = hasher.finalize()
        #expect(hasher.finalize() == first)
        #expect(first.hexString == "0bdc9d2d256b3ee9daae347be6f4dc835a467ffe")

        hasher.update(bytes: Array("bc".utf8).span)
        #expect(hasher.finalize().hexString == "8eb208f7e05d987a9b044a8e98c6b087f15a0bfc")
    }

    @Test("Hasher is a value type: copies are independent")
    func valueSemantics() {
        var original = RIPEMD160()
        original.update(bytes: Array("ab".utf8).span)
        var copy = original
        copy.update(bytes: Array("c".utf8).span)
        original.update(bytes: Array("d".utf8).span)
        #expect(copy.finalize().hexString == ripemd160("abc"))
        #expect(original.finalize().hexString == ripemd160("abd"))
    }

    @Test("Length counter handles inputs larger than a single block repeatedly")
    func largeInput() {
        let message = RIPEMD160ReferenceVectors.message(length: 65_537)
        #expect(ripemd160(message) == RIPEMD160ReferenceVectors.digests.last { $0.length == 65_537 }?.hex)
    }
}

// MARK: - Digest

@Suite("RIPEMD-160 Digest")
struct RIPEMD160DigestTests {

    let abc = RIPEMD160.hash(bytes: Array("abc".utf8).span)

    @Test("Sizes")
    func sizes() {
        #expect(RIPEMD160.Digest.byteCount == 20)
        #expect(RIPEMD160.blockByteCount == 64)
        #expect(Array(abc).count == 20)
    }

    @Test("Hex and description")
    func formatting() {
        #expect(abc.hexString == "8eb208f7e05d987a9b044a8e98c6b087f15a0bfc")
        #expect(abc.description == "RIPEMD160 digest: 8eb208f7e05d987a9b044a8e98c6b087f15a0bfc")
    }

    @Test("Sequence of bytes")
    func sequence() {
        let bytes = Array(abc)
        #expect(bytes.first == 0x8e)
        #expect(bytes.last == 0xfc)
        #expect(bytes.hex == abc.hexString)
    }

    @Test("withBytes exposes the same 20 bytes as a Span")
    func withBytes() {
        let viaSpan = abc.withBytes { span in (0..<span.count).map { span[$0] } }
        #expect(viaSpan == Array(abc))
    }

    @Test("withUnsafeBytes (ContiguousBytes) exposes the same 20 bytes")
    func withUnsafeBytes() {
        let viaPointer = unsafe abc.withUnsafeBytes { unsafe Array($0) }
        #expect(viaPointer == Array(abc))
    }

    @Test("Round-trips through init?(bytes:)")
    func roundTrip() throws {
        let bytes = Array(abc)
        let rebuilt = try #require(digest(from: bytes))
        #expect(rebuilt == abc)
    }

    @Test("init?(bytes:) rejects wrong lengths", arguments: [0, 1, 19, 21, 32])
    func wrongLength(count: Int) {
        let bytes = [UInt8](repeating: 0, count: count)
        #expect(digest(from: bytes) == nil)
    }

    @Test("Equality and hashing")
    func equalityAndHashing() {
        let abdBytes = Array("abd".utf8)
        let abcBytes = Array("abc".utf8)
        let other = RIPEMD160.hash(bytes: abdBytes.span)
        let again = RIPEMD160.hash(bytes: abcBytes.span)
        #expect(abc == again)
        #expect(abc != other)
        #expect(Set([abc, abc, other]).count == 2)
    }

    @Test("A difference in any single byte breaks equality", arguments: 0..<20)
    func singleByteDifference(index: Int) throws {
        var bytes = Array(abc)
        bytes[index] ^= 0x01
        let changed = try #require(digest(from: bytes))
        #expect(changed != abc)
    }
}

// MARK: - CryptoKit / swift-crypto protocol conformance

@Suite("RIPEMD-160 HashFunction conformance")
struct RIPEMD160ConformanceTests {

    private func hashGeneric<H: HashFunction>(_: H.Type, _ message: [UInt8]) -> [UInt8] {
        var hasher = H()
        hasher.update(data: message)
        return Array(hasher.finalize())
    }

    @Test("Usable generically as a HashFunction")
    func generic() {
        #expect(
            hashGeneric(RIPEMD160.self, Array("abc".utf8)).hex
                == "8eb208f7e05d987a9b044a8e98c6b087f15a0bfc")
    }

    @Test("Protocol one-shot hash(data:) with Data and [UInt8]")
    func oneShot() {
        let expected = "8eb208f7e05d987a9b044a8e98c6b087f15a0bfc"
        #expect(RIPEMD160.hash(data: Data("abc".utf8)).hexString == expected)
        #expect(RIPEMD160.hash(data: Array("abc".utf8)).hexString == expected)
    }

    @Test("update(bufferPointer:) agrees with the Span API")
    func bufferPointer() {
        let message = RIPEMD160ReferenceVectors.message(length: 1_000)
        var hasher = RIPEMD160()
        message.withUnsafeBytes { unsafe hasher.update(bufferPointer: $0) }
        #expect(hasher.finalize() == RIPEMD160.hash(bytes: message.span))
    }

    @Test("RawSpan overloads inherited from Crypto")
    func rawSpan() {
        let message = RIPEMD160ReferenceVectors.message(length: 1_000)
        let oneShot = RIPEMD160.hash(bytes: message.span.bytes)
        #expect(oneShot == RIPEMD160.hash(bytes: message.span))

        var hasher = RIPEMD160()
        hasher.update(bytes: message.span.bytes.extracting(0..<333))
        hasher.update(bytes: message.span.bytes.extracting(333..<1_000))
        #expect(hasher.finalize() == oneShot)
    }

    @Test("Data's span feeds the Span API")
    func dataSpan() {
        let data = Data(RIPEMD160ReferenceVectors.message(length: 777))
        let viaSpan = RIPEMD160.hash(bytes: data.span)
        #expect(viaSpan == RIPEMD160.hash(data: data))
    }

    @Test("Equal to the swift-crypto/CryptoKit result shape: 20-byte digest, 64-byte block")
    func shape() {
        #expect(RIPEMD160.Digest.byteCount == 20)
        #expect(RIPEMD160.blockByteCount == 64)
        #expect(SHA256.blockByteCount == 64)
    }
}

// MARK: - Hash160

@Suite("Hash160")
struct Hash160Tests {

    /// Generator point G, compressed; its HASH160 is a well-known constant.
    static let generator: [UInt8] = [
        0x02, 0x79, 0xbe, 0x66, 0x7e, 0xf9, 0xdc, 0xbb, 0xac, 0x55, 0xa0, 0x62, 0x95, 0xce, 0x87, 0x0b,
        0x07, 0x02, 0x9b, 0xfc, 0xdb, 0x2d, 0xce, 0x28, 0xd9, 0x59, 0xf2, 0x81, 0x5b, 0x16, 0xf8, 0x17, 0x98,
    ]

    @Test("Known vector")
    func knownVector() {
        #expect(Hash160.hash(data: Self.generator).hexString == "751e76e8199196d454941c45d1b3a323f1433bd6")
    }

    @Test("Empty input: RIPEMD160(SHA256(\"\"))")
    func empty() {
        #expect(Hash160.hash(data: [UInt8]()).hexString == "b472a266d0bd89c13706a4132ccfb16f7c3b9fcb")
    }

    @Test("Matches the explicit two-step composition", arguments: [0, 1, 32, 33, 55, 64, 65, 200, 1000])
    func matchesComposition(length: Int) {
        let message = RIPEMD160ReferenceVectors.message(length: length)
        let expected = ripemd160(Array(SHA256.hash(data: message)))
        #expect(Hash160.hash(data: message).hexString == expected)
    }

    @Test("The 32-byte fast path equals the streaming path for arbitrary input")
    func fastPathEqualsStreaming() {
        for seed in 0..<500 {
            let message = (0..<32).map { UInt8(truncatingIfNeeded: $0 &* 131 &+ seed &* 17 &+ seed >> 3) }
            let fast = RIPEMD160.hash32(message.span)
            #expect(fast == RIPEMD160.hash(bytes: message.span), "seed \(seed)")
        }
    }

    @Test("Incremental updates match one-shot")
    func incremental() {
        let message = RIPEMD160ReferenceVectors.message(length: 500)
        var hasher = Hash160()
        hasher.update(data: message[..<123])
        hasher.update(data: message[123...])
        #expect(hasher.finalize() == Hash160.hash(data: message))
    }

    @Test("blockByteCount follows SHA-256")
    func blockSize() {
        #expect(Hash160.blockByteCount == 64)
    }
}
