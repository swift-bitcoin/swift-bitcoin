import BitcoinBase
import Testing

private func txids(_ display: [String]) -> [TransactionIdentifier] {
    display.map { TransactionIdentifier(displayHex: $0)! }
}

/// Synthetic transaction identifiers: `HASH256` of the index as a little-endian `UInt16`.
private func syntheticTransactionIdentifiers(_ count: Int) -> [TransactionIdentifier] {
    (0..<count).map { i in TransactionIdentifier(doubleSHA256([UInt8(i & 0xFF), UInt8(i >> 8)])) }
}

/// A deliberately simple model: concatenate byte arrays, duplicate the last on odd levels.
private func referenceRoot(_ ids: [TransactionIdentifier]) -> [UInt8] {
    var level = ids.map { bytes(of: $0.hash) }
    while level.count > 1 {
        if !level.count.isMultiple(of: 2) { level.append(level.last!) }
        level = stride(from: 0, to: level.count, by: 2).map { bytes(of: doubleSHA256(level[$0] + level[$0 + 1])) }
    }
    return level[0]
}

@Suite("MerkleRoot")
struct MerkleRootTests {
    @Suite struct MainnetBlocks {
        /// A single transaction is its own root.
        @Test func genesis() throws {
            let coinbase = try #require(TransactionIdentifier(displayHex: Fixtures.genesisMerkleRoot))
            let (root, isMutated) = MerkleRoot.compute(transactionIdentifiers: [coinbase])
            #expect(root.hash == coinbase.hash)
            #expect(root.displayHex == Fixtures.genesisMerkleRoot)
            #expect(!isMutated)
        }

        /// Block 170: the coinbase and the first payment between people.
        @Test func block170() {
            let ids = txids([
                "b1fea52486ce0c62bb442b530a3f0132b826c74e473d1f2c220bfa78111c5082",
                "f4184fc596403b9d638783cf57adfe4c75c605f6356fbc91338530e9831e9e16",
            ])
            #expect(
                MerkleRoot(transactionIdentifiers: ids).displayHex
                    == "7dac2c5666815c17a3b36427de37bb9d2e2c5ccec3f8633eb91a4205cb4c10ff")
        }

        @Test func block100000() {
            let ids = txids([
                "8c14f0db3df150123e6f3dbbf30f8b955a8249b62ac1d1ff16284aefa3d06d87",
                "fff2525b8931402dd09222c50775608f75787bd2b87e56995a7bdd30f79702c4",
                "6359f0868171b1d194cbee1af2f16ea598ae8fad666d9b012c8ed2b79a236ec4",
                "e9a66845e05d5abc0ad04ec80f774a7e585c6e8db975962d069a522137b80c1d",
            ])
            #expect(
                MerkleRoot(transactionIdentifiers: ids).displayHex
                    == "f3e94742aca4b5ef85488dc37c06c3282295ffec960994b2c0d5ac2a25a95766")
        }

        @Test func orderMatters() {
            let ids = txids([
                "b1fea52486ce0c62bb442b530a3f0132b826c74e473d1f2c220bfa78111c5082",
                "f4184fc596403b9d638783cf57adfe4c75c605f6356fbc91338530e9831e9e16",
            ])
            #expect(MerkleRoot(transactionIdentifiers: ids) != MerkleRoot(transactionIdentifiers: ids.reversed()))
        }
    }

    @Suite struct TreeShapes {
        /// Expected roots computed with Python's `hashlib`, covering odd levels at every depth.
        @Test(arguments: [
            (1, "905c0ed9955a5c67b7edc8881fe862fddce009a2294ef8f4ba03834b4aeb7f40"),
            (2, "b3184fa362df10302be23f54e302b4b1313eced6dc60feedfac4a5631eb4a706"),
            (3, "0337db0345c4aff941d17ae689a790bdf7a9163157785cf2d1f531b0c5963679"),
            (4, "f412e999aeb988df6b43511306d8b4117ecde66ad79dfdb87a8298bc31ea4eb4"),
            (5, "a1d6faa7bd9e88033145ee39aca1bd777c163b3cdb4b65c4ae588e4ac01d8bb1"),
            (6, "386b38305e182e3091847390f870c55f17df4acddb55d44e3f3a212eec77289b"),
            (7, "a3e938531a06303639b1bcdda04649e9d4782a4f1e54c20c9e217415325cd4fc"),
            (8, "1f9cda8eef47f55026ada100679668c6778c224a57000b1e278fbf09db4940ab"),
            (9, "a547f3b0674d115cd32de5cb667e6d38db4b41ed425e48c1ed3f20404a695e71"),
            (15, "c39dc3df8360715c08317f99fd30c0e8a5278a482bbe40541f0fbb1d66c72a04"),
            (16, "39e5951cbeebd42d0e38fe97f05059199a3e4cf53e4267ec2cd3f7c9c6645d97"),
            (17, "fc474f6906a35b012fa12c240219adc621fc03c85082fe063790a008bca4b373"),
            (100, "fdb2942208b7259afdb122b676eb3a706dfbbd39083c28ab855df3fb3b25bccd"),
            (1_000, "880802b0daa82cf91018c872c216caa7eadd89b75cc5b9726d61a31698bce95d"),
        ])
        func matchesPython(count: Int, expected: String) throws {
            let ids = syntheticTransactionIdentifiers(count)
            let (root, isMutated) = MerkleRoot.compute(transactionIdentifiers: ids)
            #expect(MerkleRoot(transactionIdentifiers: ids) == root)
            #expect(root.displayHex == expected)
            #expect(!isMutated)
        }

        @Test func matchesReferenceForEveryCountUpTo300() {
            let all = syntheticTransactionIdentifiers(300)
            for count in 1...300 {
                let ids = Array(all.prefix(count))
                #expect(bytes(of: MerkleRoot(transactionIdentifiers: ids).hash) == referenceRoot(ids), "\(count)")
            }
        }

        /// As in Bitcoin Core: no transactions give the all-zero root, which no header can match.
        @Test func emptyIsZero() {
            let zero = MerkleRoot.zero
            let (root, isMutated) = MerkleRoot.compute(transactionIdentifiers: [TransactionIdentifier]())
            #expect(root == zero)
            #expect(!isMutated)
            #expect(MerkleRoot(transactionIdentifiers: [TransactionIdentifier]()) == zero)
        }

        /// Any collection of identifiers works, and the input isn't modified.
        @Test func acceptsAnyCollection() {
            let ids = syntheticTransactionIdentifiers(9)
            let expected = MerkleRoot(transactionIdentifiers: ids)
            #expect(MerkleRoot(transactionIdentifiers: ids[...]) == expected)
            #expect(MerkleRoot(transactionIdentifiers: ids.lazy.map { $0 }) == expected)
            #expect(MerkleRoot(transactionIdentifiers: ContiguousArray(ids)) == expected)
            #expect(
                MerkleRoot(transactionIdentifiers: Array(syntheticTransactionIdentifiers(12)[3...]))
                    == MerkleRoot(transactionIdentifiers: Array(syntheticTransactionIdentifiers(12).dropFirst(3))))
            #expect(ids == syntheticTransactionIdentifiers(9))
        }
    }

    /// CVE-2012-2459: duplicating trailing transactions keeps the root but must be flagged.
    @Suite struct Mutation {
        @Test func duplicatedLastTransaction() throws {
            let ids = syntheticTransactionIdentifiers(3)
            let honest = MerkleRoot.compute(transactionIdentifiers: ids)
            let mutated = MerkleRoot.compute(transactionIdentifiers: ids + [ids[2]])
            #expect(honest.root == mutated.root)
            #expect(!honest.isMutated)
            #expect(mutated.isMutated)
        }

        /// The duplicate pair can sit higher up: [a, b, a, b] pairs hash(a,b) with itself.
        @Test func duplicatedSubtree() throws {
            let ids = syntheticTransactionIdentifiers(2)
            #expect(MerkleRoot.compute(transactionIdentifiers: ids + ids).isMutated)
            #expect(MerkleRoot.compute(transactionIdentifiers: ids).isMutated == false)
        }

        /// Two equal transactions anywhere in a pair are a mutation, even a single pair.
        @Test func identicalPair() throws {
            let a = syntheticTransactionIdentifiers(1)[0]
            #expect(MerkleRoot.compute(transactionIdentifiers: [a, a]).isMutated)
            #expect(MerkleRoot.compute(transactionIdentifiers: [a]).isMutated == false)
        }

        /// Equal identifiers that are never paired together aren't a mutation.
        @Test func equalButNotPaired() throws {
            let ids = syntheticTransactionIdentifiers(3)
            #expect(MerkleRoot.compute(transactionIdentifiers: [ids[0], ids[1], ids[0], ids[2]]).isMutated == false)
        }

        /// The odd-level self-pairing is part of the algorithm, not a mutation.
        @Test(arguments: [3, 5, 7, 9, 11, 13, 100, 1_000])
        func oddCountsAreNotMutations(count: Int) throws {
            #expect(
                MerkleRoot.compute(transactionIdentifiers: syntheticTransactionIdentifiers(count)).isMutated == false)
        }

        /// Detection only adds the flag: the root is the same with and without it, mutated or not.
        @Test func detectionDoesNotChangeTheRoot() {
            let ids = syntheticTransactionIdentifiers(5)
            for list in [ids, ids + [ids[4]], ids + ids] {
                #expect(
                    MerkleRoot.compute(transactionIdentifiers: list).root == MerkleRoot(transactionIdentifiers: list))
            }
        }
    }

    @Suite struct Witness {
        private static let zero = hash([UInt8](repeating: 0, count: 32))

        private static func wtxids(_ count: Int) -> [WitnessTransactionIdentifier] {
            syntheticTransactionIdentifiers(count).map { WitnessTransactionIdentifier($0.hash) }
        }

        /// The witness tree is the transaction tree over wtxids, with the coinbase's set to zero.
        @Test(arguments: [1, 2, 3, 4, 7, 100])
        func coinbaseLeafIsZero(count: Int) {
            let ids = Self.wtxids(count)
            let leaves = [Self.zero] + ids.dropFirst().map(\.hash)
            let expected = referenceRoot(leaves.map(TransactionIdentifier.init))
            #expect(bytes(of: WitnessMerkleRoot(witnessTransactionIdentifiers: ids).hash) == expected)
            #expect(
                WitnessMerkleRoot.compute(witnessTransactionIdentifiers: ids).root
                    == WitnessMerkleRoot(witnessTransactionIdentifiers: ids))
        }

        /// Whatever is passed for the coinbase is ignored.
        @Test func coinbaseValueIsIgnored() {
            var ids = Self.wtxids(5)
            let original = WitnessMerkleRoot(witnessTransactionIdentifiers: ids)
            ids[0] = WitnessTransactionIdentifier(randomHashes(1, seed: 60)[0])
            #expect(WitnessMerkleRoot(witnessTransactionIdentifiers: ids) == original)
        }

        /// A coinbase-only block's witness root is zero.
        @Test func coinbaseOnly() {
            #expect(WitnessMerkleRoot(witnessTransactionIdentifiers: Self.wtxids(1)).hash == Self.zero)
            #expect(
                WitnessMerkleRoot(witnessTransactionIdentifiers: [WitnessTransactionIdentifier]()).hash == Self.zero)
        }

        /// Without witness data wtxids equal txids, so the trees differ only in the coinbase leaf.
        @Test func matchesTransactionTreeExceptCoinbase() {
            let txids = syntheticTransactionIdentifiers(6)
            var withZeroCoinbase = txids
            withZeroCoinbase[0] = TransactionIdentifier(Self.zero)
            let wtxids = txids.map { WitnessTransactionIdentifier($0.hash) }
            #expect(
                WitnessMerkleRoot(witnessTransactionIdentifiers: wtxids).hash
                    == MerkleRoot(transactionIdentifiers: withZeroCoinbase).hash)
        }

        @Test func reportsMutation() {
            let ids = Self.wtxids(3)
            #expect(!WitnessMerkleRoot.compute(witnessTransactionIdentifiers: ids).isMutated)
            #expect(WitnessMerkleRoot.compute(witnessTransactionIdentifiers: ids + [ids[2]]).isMutated)
        }

        /// The coinbase commitment: HASH256(witness root || witness reserved value).
        @Test(arguments: [0, 1, 2])
        func commitment(reservedSeed: Int) {
            let root = WitnessMerkleRoot(witnessTransactionIdentifiers: Self.wtxids(4))
            let reserved = reservedSeed == 0 ? Self.zero : randomHashes(1, seed: UInt64(70 + reservedSeed))[0]
            #expect(
                root.commitment(witnessReservedValue: reserved)
                    == doubleSHA256(bytes(of: root.hash) + bytes(of: reserved)))
        }
    }
}
