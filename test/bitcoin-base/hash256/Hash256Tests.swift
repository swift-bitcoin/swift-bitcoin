import BinaryParsing
import BitcoinBase
import Crypto
import Foundation
import Testing

@Suite("Hash256")
struct Hash256Tests {
    @Suite struct Layout {
        @Test func isThirtyTwoUnalignedBytes() {
            #expect(Hash256.byteCount == 32)
            #expect(MemoryLayout<Hash256>.size == 32)
            #expect(MemoryLayout<Hash256>.stride == 32)
            #expect(MemoryLayout<Hash256>.alignment == 1)
        }

        /// Alignment 1 means no padding next to other fields.
        @Test func packsWhenEmbedded() {
            struct Flagged {
                var hash: Hash256
                var flag: Bool
            }
            struct Indexed {
                var hash: Hash256
                var index: UInt32
            }
            #expect(MemoryLayout<Flagged>.stride == 33)
            #expect(MemoryLayout<Indexed>.stride == 36)
        }
    }

    @Suite struct Construction {
        @Test(arguments: BytePattern.all)
        func allInitializersAgree(_ pattern: BytePattern) throws {
            let expected = hash(pattern.bytes)
            let inline = InlineArray<32, UInt8> { pattern.bytes[$0] }
            let padded = [0xEE] + pattern.bytes + [0xEE]

            let data = Data(pattern.bytes)
            // Spans can't be captured by #expect's closure, so build the values first.
            let fromSpan = Hash256(bytes: pattern.bytes.span)
            let fromRawSpan = Hash256(bytes: pattern.bytes.span.bytes)
            let fromData = Hash256(bytes: data.bytes)
            let fromSlice = Hash256(bytes: padded.span.extracting(1..<33))

            #expect(Hash256(inline) == expected)
            #expect(fromSpan == expected)
            #expect(fromRawSpan == expected)
            #expect(fromData == expected)
            #expect(fromSlice == expected)
            #expect(bytes(of: expected) == pattern.bytes)
            #expect(expected.bytes.indices.allSatisfy { expected.bytes[$0] == pattern.bytes[$0] })
        }

        @Test func fromCryptoKitDigest() {
            #expect(
                Hash256(SHA256.hash(data: Data())).hexString
                    == "e3b0c44298fc1c149afbf4c8996fb92427ae41e4649b934ca495991b7852b855")
            #expect(
                Hash256(SHA256.hash(data: Data("abc".utf8))).hexString
                    == "ba7816bf8f01cfea414140de5dae2223b00361a396177a9cb410ff61f20015ad")
        }

        @Test(arguments: [0, 1, 16, 31, 33, 64])
        func rejectsWrongLength(count: Int) {
            let array = [UInt8](repeating: 0xAB, count: count)
            let data = Data(count: count)
            let fromSpan = Hash256(bytes: array.span)
            let fromRawSpan = Hash256(bytes: array.span.bytes)
            let fromData = Hash256(bytes: data.bytes)
            #expect(fromSpan == nil)
            #expect(fromRawSpan == nil)
            #expect(fromData == nil)
        }

        @Test func bytesAreMutable() {
            var hash = hash([UInt8](repeating: 0, count: 32))
            hash.bytes[0] = 0x01
            hash.bytes[31] = 0xFF
            #expect(hash.hexString == "01" + String(repeating: "0", count: 60) + "ff")
            #expect(hash.displayHex == "ff" + String(repeating: "0", count: 60) + "01")
        }
    }

    @Suite struct DoubleSHA256 {
        @Test func knownVectors() {
            let empty = [UInt8]()
            let genesis = Fixtures.genesisHeader
            let block1 = Fixtures.block1Header
            let emptyHash = Hash256(hashing: empty.span)
            let genesisHash = Hash256(hashing: genesis.span)
            let block1Hash = Hash256(hashing: block1.span)
            #expect(emptyHash.hexString == "5df6e0e2761359d30a8275058e299fcc0381534545f55cf43e41983f5d4c9456")
            #expect(genesisHash.displayHex == Fixtures.genesisHash)
            #expect(block1Hash.displayHex == Fixtures.block1Hash)
        }

        /// Every input form gives the same result as CryptoKit applied twice.
        @Test(arguments: [0, 1, 31, 32, 55, 56, 63, 64, 65, 80, 1_000])
        func allInputFormsAgree(length: Int) {
            var rng = SplitMix64(seed: UInt64(length))
            let input = (0..<length).map { _ in UInt8.random(in: .min ... .max, using: &rng) }
            let expected = doubleSHA256(input)
            let data = Data(input)
            let fromSpan = Hash256(hashing: input.span)
            let fromRawSpan = Hash256(hashing: input.span.bytes)
            let fromData = Hash256(hashing: data.bytes)
            #expect(fromSpan == expected)
            #expect(fromRawSpan == expected)
            #expect(fromData == expected)
        }

        /// Hashing a slice of a span, as when hashing a header inside a parsed block.
        @Test func hashesASubrange() {
            let block = [0xAA] + Fixtures.genesisHeader + [0xBB, 0xCC]
            let hash = Hash256(hashing: block.span.bytes.extracting(1..<81))
            #expect(BlockHash(hash).displayHex == Fixtures.genesisHash)
        }
    }

    @Suite struct HexFormats {
        @Test func zeroAndMax() {
            let zero = hash([UInt8](repeating: 0, count: 32))
            let max = hash([UInt8](repeating: 0xFF, count: 32))
            #expect(zero.hexString == String(repeating: "0", count: 64))
            #expect(zero.displayHex == String(repeating: "0", count: 64))
            #expect(max.hexString == String(repeating: "f", count: 64))
            #expect(max.displayHex == String(repeating: "f", count: 64))
        }

        /// `hexString` is wire order; `displayHex` reverses it, so byte 0 prints last.
        @Test func byteOrder() {
            let first = hash(BytePattern.all.first { $0.name == "first byte only" }!.bytes)
            #expect(first.hexString == "01" + String(repeating: "0", count: 62))
            #expect(first.displayHex == String(repeating: "0", count: 62) + "01")
            let ascending = hash(Array(0..<32))
            #expect(ascending.hexString.hasPrefix("000102"))
            #expect(ascending.displayHex.hasPrefix("1f1e1d"))
        }

        @Test func padsSingleDigitBytes() {
            #expect(hash([UInt8](repeating: 0x0A, count: 32)).hexString == String(repeating: "0a", count: 32))
        }

        @Test(arguments: BytePattern.all)
        func displayHexRoundTrips(_ pattern: BytePattern) throws {
            let original = hash(pattern.bytes)
            let display = original.displayHex
            #expect(display.count == 64)
            #expect(display == display.lowercased())
            #expect(Hash256(displayHex: display) == original)
            #expect(Hash256(displayHex: display.uppercased()) == original)
            #expect(Hash256(displayHex: "0x" + display) == original)
            #expect(Hash256(displayHex: "0X" + display) == original)
            #expect(original.hexString == hex(pattern.bytes))
            #expect(display == hex(pattern.bytes.reversed()))
        }

        @Test func randomRoundTrips() {
            for original in randomHashes(500, seed: 1) {
                #expect(Hash256(displayHex: original.displayHex) == original)
                #expect(original.displayHex == hex(bytes(of: original).reversed()))
            }
        }

        @Test func mixedCase() {
            let mixed = "000000000019D6689c085AE165831e934FF763ae46a2a6c172b3f1b60a8ce26F"
            #expect(Hash256(displayHex: mixed)?.displayHex == Fixtures.genesisHash)
        }

        @Test(arguments: Fixtures.malformedDisplayHex)
        func rejectsMalformedDisplayHex(_ text: String) {
            #expect(Hash256(displayHex: text) == nil)
        }
    }

    @Suite struct Zero {
        @Test func isAllZeroBytes() {
            #expect(bytes(of: .zero) == [UInt8](repeating: 0, count: 32))
            #expect(Hash256.zero.displayHex == String(repeating: "0", count: 64))
            #expect(Hash256(displayHex: String(repeating: "0", count: 64)) == .zero)
            #expect(Hash256.zero.isZero)
        }

        @Test(arguments: BytePattern.all)
        func isZeroOnlyForTheZeroPattern(_ pattern: BytePattern) {
            #expect(hash(pattern.bytes).isZero == pattern.bytes.allSatisfy { $0 == 0 })
        }

        /// Any single set bit, on either side of the 16-byte word boundary, makes it non-zero.
        @Test func anySetBitIsNonZero() {
            for bit in 0..<256 {
                #expect(!hash(singleBit(bit)).isZero, "bit \(bit)")
            }
        }
    }

    @Suite struct DebugDescription {
        @Test func spellsOutTheDisplayOrder() {
            let genesis = Hash256(displayHex: Fixtures.genesisHash)!
            #expect(genesis.debugDescription == "Hash256(displayHex: \"\(Fixtures.genesisHash)\")")
            #expect(String(reflecting: genesis) == genesis.debugDescription)
        }

        /// The identifier types keep printing as plain display hex.
        @Test func identifiersPrintDisplayHex() {
            let block = BlockHash(Hash256(displayHex: Fixtures.genesisHash)!)
            #expect("\(block)" == Fixtures.genesisHash)
            #expect(String(reflecting: block) == Fixtures.genesisHash)
        }
    }

    @Suite struct Equality {
        @Test(arguments: BytePattern.all)
        func equalsAnIndependentCopy(_ pattern: BytePattern) {
            let a = hash(pattern.bytes)
            let b = Hash256(displayHex: a.displayHex)!
            #expect(a == a)
            #expect(a == b)
            #expect(b == a)
        }

        /// Equality must notice a difference in any bit, including either side of the word boundary.
        @Test(arguments: 0..<256)
        func singleBitDifference(bit: Int) {
            let base = randomHashes(1, seed: 2)[0]
            var flipped = bytes(of: base)
            flipped[bit / 8] ^= 1 << (bit % 8)
            #expect(base != hash(flipped))
            #expect(hash(flipped) != base)
        }

        @Test func patternsAreEqualOnlyToThemselves() {
            for a in BytePattern.all {
                for b in BytePattern.all {
                    #expect((hash(a.bytes) == hash(b.bytes)) == (a.bytes == b.bytes), "\(a.name) vs \(b.name)")
                }
            }
        }
    }

    @Suite struct Hashing {
        @Test(arguments: BytePattern.all)
        func equalValuesHashEqually(_ pattern: BytePattern) {
            let a = hash(pattern.bytes)
            let b = Hash256(displayHex: a.displayHex)!
            #expect(a.hashValue == b.hashValue)
        }

        @Test func singleBitVariantsAreDistinctKeys() {
            let variants = (0..<256).map { hash(singleBit($0)) } + [hash([UInt8](repeating: 0, count: 32))]
            #expect(Set(variants).count == 257)
        }

        /// Only the first 8 bytes are hashed: values differing only after them hash alike, yet
        /// stay distinct keys because equality compares all 32 bytes.
        @Test func hashesTheFirstEightBytesOnly() {
            let base = randomHashes(1, seed: 110)[0]
            let variants = (64..<256).map { bit -> Hash256 in
                var flipped = bytes(of: base)
                flipped[bit / 8] ^= 1 << (bit % 8)
                return hash(flipped)
            }
            for variant in variants {
                #expect(variant.hashValue == base.hashValue)
            }
            let keys = Set(variants + [base])
            #expect(keys.count == variants.count + 1)
            #expect(variants.allSatisfy { keys.contains($0) })
        }

        /// A difference in the hashed bytes changes the hash value.
        @Test(arguments: 0..<64)
        func firstEightBytesAffectTheHash(bit: Int) {
            let base = randomHashes(1, seed: 111)[0]
            var flipped = bytes(of: base)
            flipped[bit / 8] ^= 1 << (bit % 8)
            #expect(hash(flipped).hashValue != base.hashValue)
        }

        @Test func randomValuesAreDistinctKeys() {
            #expect(Set(randomHashes(10_000, seed: 3)).count == 10_000)
        }

        @Test func dictionaryLookupWithFreshKeys() {
            let keys = randomHashes(1_000, seed: 4)
            let table = Dictionary(uniqueKeysWithValues: keys.enumerated().map { ($1, $0) })
            for (offset, key) in keys.enumerated() {
                #expect(table[Hash256(displayHex: key.displayHex)!] == offset)
            }
            #expect(table[randomHashes(1, seed: 5)[0]] == nil)
        }
    }

    @Suite struct BinaryCoding {
        @Test(arguments: BytePattern.all)
        func roundTripsInWireOrder(_ pattern: BytePattern) throws {
            let original = hash(pattern.bytes)
            let wire = encoded(byteCount: 32) { original.encode(into: &$0) }
            #expect(wire == pattern.bytes)
            #expect(try Hash256(parsing: wire) == original)
            #expect(try Hash256(parsing: Data(wire)) == original)
        }

        @Test(arguments: 0..<32)
        func throwsOnShortInput(count: Int) {
            #expect(throws: ParsingError.self) { try Hash256(parsing: [UInt8](repeating: 0, count: count)) }
        }

        @Test func parsesConsecutivelyAndLeavesTheRest() throws {
            let hashes = randomHashes(3, seed: 6)
            let input = hashes.flatMap(bytes(of:)) + [1, 2, 3, 4, 5]
            let (parsed, remaining) = try input.withParserSpan { span in
                (try (0..<3).map { _ in try Hash256(parsing: &span) }, span.count)
            }
            #expect(parsed == hashes)
            #expect(remaining == 5)
        }

        /// The fast path loads straight from the input, so check odd offsets inside a larger buffer.
        @Test(arguments: [1, 3, 7, 15, 17, 31])
        func parsesAtUnalignedOffsets(offset: Int) throws {
            let hashes = randomHashes(2, seed: UInt64(90 + offset))
            let input = [UInt8](repeating: 0xEE, count: offset) + hashes.flatMap(bytes(of:))
            let parsed = try input.withParserSpan { span in
                _ = try span.extract(byteCount: offset)
                return [try Hash256(parsing: &span), try Hash256(parsing: &span)]
            }
            #expect(parsed == hashes)
        }

        /// A failed parse leaves the input where it was, so a caller can report or retry.
        @Test func shortInputConsumesNothing() {
            let remaining = [UInt8](repeating: 0, count: 31).withParserSpan { span in
                #expect(throws: ParsingError.self) { try Hash256(parsing: &span) }
                return span.count
            }
            #expect(remaining == 31)
        }

        @Test func encodesConsecutively() {
            let hashes = randomHashes(2, seed: 7)
            let wire = encoded(byteCount: 64) { output in
                for hash in hashes {
                    hash.encode(into: &output)
                }
                #expect(output.freeCapacity == 0)
            }
            #expect(wire == hashes.flatMap(bytes(of:)))
        }

        @Test func encodingTrapsWithoutRoom() async {
            await #expect(processExitsWith: .failure) {
                let hash = Hash256.zero
                withTemporaryAllocation(byteCount: 31, alignment: 1) { hash.encode(into: &$0) }
            }
        }
    }
}
