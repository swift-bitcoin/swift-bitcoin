import BinaryParsing
import Foundation
import BitcoinBase
//import BitcoinCrypto
import Testing

private let identifierTypes: [any Hash256Identifier.Type] = [
    TransactionIdentifier.self, WitnessTransactionIdentifier.self, BlockHash.self, MerkleRoot.self, WitnessMerkleRoot.self,
]

@Suite("Hash256 identifiers")
struct IdentifierTests {
    @Test(arguments: identifierTypes)
    func sameLayoutAsHash256(_ type: any Hash256Identifier.Type) {
        func check<ID: Hash256Identifier>(_: ID.Type) {
            #expect(MemoryLayout<ID>.size == 32)
            #expect(MemoryLayout<ID>.stride == 32)
            #expect(MemoryLayout<ID>.alignment == 1)
        }
        check(type)
    }

    @Test(arguments: identifierTypes)
    func wrapsAndUnwraps(_ type: any Hash256Identifier.Type) {
        func check<ID: Hash256Identifier>(_: ID.Type) {
            for pattern in BytePattern.all {
                #expect(ID(hash(pattern.bytes)).hash == hash(pattern.bytes), "\(pattern.name)")
            }
        }
        check(type)
    }

    @Test(arguments: identifierTypes)
    func equalityAndHashingFollowTheHash(_ type: any Hash256Identifier.Type) {
        func check<ID: Hash256Identifier>(_: ID.Type) {
            for a in BytePattern.all {
                for b in BytePattern.all {
                    let lhs = ID(hash(a.bytes)), rhs = ID(hash(b.bytes))
                    #expect((lhs == rhs) == (a.bytes == b.bytes), "\(a.name) vs \(b.name)")
                    if lhs == rhs { #expect(lhs.hashValue == rhs.hashValue) }
                }
            }
            let keys = randomHashes(1_000, seed: 10).map(ID.init)
            #expect(Set(keys).count == 1_000)
            let table = Dictionary(uniqueKeysWithValues: keys.enumerated().map { ($1, $0) })
            for (offset, key) in keys.enumerated() {
                #expect(table[ID(displayHex: key.displayHex)!] == offset)
            }
        }
        check(type)
    }

    @Test(arguments: identifierTypes)
    func displayHexMatchesHash256(_ type: any Hash256Identifier.Type) {
        func check<ID: Hash256Identifier>(_: ID.Type) {
            for original in randomHashes(200, seed: 11) {
                let id = ID(original)
                #expect(id.displayHex == original.displayHex)
                #expect(id.description == original.displayHex)
                #expect("\(id)" == original.displayHex)
                #expect(ID(displayHex: id.displayHex) == id)
                #expect(ID(displayHex: "0x" + id.displayHex.uppercased()) == id)
            }
            for text in Fixtures.malformedDisplayHex {
                #expect(ID(displayHex: text) == nil, "\(text)")
            }
        }
        check(type)
    }

    @Test(arguments: identifierTypes)
    func binaryCodingRoundTrips(_ type: any Hash256Identifier.Type) throws {
        func check<ID: Hash256Identifier>(_: ID.Type) throws {
            for pattern in BytePattern.all {
                let id = ID(hash(pattern.bytes))
                let wire = encoded(byteCount: 32) { id.encode(into: &$0) }
                #expect(wire == pattern.bytes)
                #expect(try ID(parsing: wire) == id)
                #expect(try ID(parsing: Data(wire)) == id)
            }
            for count in [0, 1, 31] {
                #expect(throws: ParsingError.self) { try ID(parsing: [UInt8](repeating: 0, count: count)) }
            }
        }
        try check(type)
    }

    @Test(arguments: identifierTypes)
    func zero(_ type: any Hash256Identifier.Type) {
        func check<ID: Hash256Identifier>(_: ID.Type) {
            #expect(ID.zero.hash == .zero)
            #expect(ID.zero.isZero)
            #expect(ID.zero == ID(.zero))
            #expect(ID.zero.displayHex == String(repeating: "0", count: 64))
            for hash in randomHashes(20, seed: 120) {
                #expect(!ID(hash).isZero)
            }
        }
        check(type)
    }

    /// The same bytes make equal values within a type; the types themselves can't be compared
    /// or mixed, which the compiler enforces.
    @Test func sameBytesDifferentTypes() {
        let shared = hash(Array(0..<32))
        #expect(TransactionIdentifier(shared).hash == BlockHash(shared).hash)
        #expect(TransactionIdentifier(shared).displayHex == BlockHash(shared).displayHex)
    }
}

/// An 80-byte block header, parsed with the identifier types as components.
private struct Header: ExpressibleByParsing, Equatable {
    var version: UInt32
    var previousBlock: BlockHash
    var merkleRoot: MerkleRoot
    var time: UInt32
    var bits: UInt32
    var nonce: UInt32

    init(parsing input: inout ParserSpan) throws(ParsingError) {
        version = try UInt32(parsingLittleEndian: &input)
        previousBlock = try BlockHash(parsing: &input)
        merkleRoot = try MerkleRoot(parsing: &input)
        time = try UInt32(parsingLittleEndian: &input)
        bits = try UInt32(parsingLittleEndian: &input)
        nonce = try UInt32(parsingLittleEndian: &input)
    }

    func encode(into output: inout OutputRawSpan) {
        output.append(version, as: UInt32.self, .littleEndian)
        previousBlock.encode(into: &output)
        merkleRoot.encode(into: &output)
        output.append(time, as: UInt32.self, .littleEndian)
        output.append(bits, as: UInt32.self, .littleEndian)
        output.append(nonce, as: UInt32.self, .littleEndian)
    }
}

@Suite("Mainnet headers")
struct MainnetHeaderTests {
    @Test func genesis() throws {
        let header = try Header(parsing: Fixtures.genesisHeader)
        #expect(header.version == 1)
        #expect(header.previousBlock == .zero)
        #expect(header.previousBlock.isZero)
        #expect(header.merkleRoot.displayHex == Fixtures.genesisMerkleRoot)
        #expect(header.time == 1_231_006_505)
        #expect(header.bits == 0x1D00_FFFF)
        #expect(header.nonce == 2_083_236_893)

        let blockHash = BlockHash(doubleSHA256(Fixtures.genesisHeader))
        #expect(blockHash.displayHex == Fixtures.genesisHash)
        #expect(blockHash.satisfiesProofOfWork(compact: header.bits, powLimit: Fixtures.mainnetPowLimit))
    }

    @Test func blockOneChainsToGenesis() throws {
        let header = try Header(parsing: Fixtures.block1Header)
        #expect(header.previousBlock == BlockHash(doubleSHA256(Fixtures.genesisHeader)))
        #expect(!header.previousBlock.isZero)
        #expect(header.merkleRoot.displayHex == Fixtures.block1MerkleRoot)
        #expect(header.time == 1_231_469_665)
        #expect(header.nonce == 2_573_394_689)

        let blockHash = BlockHash(doubleSHA256(Fixtures.block1Header))
        #expect(blockHash.displayHex == Fixtures.block1Hash)
        #expect(blockHash.satisfiesProofOfWork(compact: header.bits, powLimit: Fixtures.mainnetPowLimit))
    }

    @Test(arguments: [Fixtures.genesisHeader, Fixtures.block1Header])
    func reencodesByteForByte(_ raw: [UInt8]) throws {
        let header = try Header(parsing: raw)
        #expect(encoded(byteCount: 80) { header.encode(into: &$0) } == raw)
    }
}
