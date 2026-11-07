import BitcoinCrypto
import Foundation

// Merkle roots, following Bitcoin Core's `consensus/merkle.cpp`:
//
// | Bitcoin Core                          | here                                               |
// |---------------------------------------|----------------------------------------------------|
// | `ComputeMerkleRoot(hashes, mutated)`  | `computeMerkleRoot(_:detectMutation:)` (internal)   |
// | `BlockMerkleRoot(block, &mutated)`    | `MerkleRoot.compute(transactionIdentifiers:)`        |
// | `BlockMerkleRoot(block)`              | `MerkleRoot(transactionIdentifiers:)`                |
// | `BlockWitnessMerkleRoot(block, ...)`  | `WitnessMerkleRoot.compute(witnessTransactionIdentifiers:)`, `init(...)` |
//
// See the MerkleRoots article in the documentation catalog for how validation uses the results.

extension MerkleRoot {
    /// The merkle root of a block's transactions, and whether the tree is mutated.
    ///
    /// Equivalent to Bitcoin Core's `BlockMerkleRoot(block, &mutated)`. Pass the transaction
    /// identifiers in block order, coinbase first.
    ///
    /// `isMutated` is true when two identical hashes are paired at any level (CVE-2012-2459): a
    /// transaction list with duplicates appended can produce the same root as the honest one. When
    /// validating a received block, treat either a root mismatch or `isMutated` as a mutated block:
    /// discard that copy without marking the header invalid.
    ///
    /// An empty list gives the all-zero root, as in Bitcoin Core; it can never match a real header.
    public static func compute(
        transactionIdentifiers: some Collection<TransactionIdentifier>
    ) -> (root: MerkleRoot, isMutated: Bool) {
        var hashes = transactionIdentifiers.map(\.hash)
        let (root, isMutated) = computeMerkleRoot(&hashes, detectMutation: true)
        return (MerkleRoot(root), isMutated)
    }

    /// The merkle root of a block's transactions, without mutation detection.
    ///
    /// Equivalent to Bitcoin Core's `BlockMerkleRoot(block)`. For transaction lists you built
    /// yourself, such as a block template; to validate a received block, use
    /// `compute(transactionIdentifiers:)`.
    public init(transactionIdentifiers: some Collection<TransactionIdentifier>) {
        var hashes = transactionIdentifiers.map(\.hash)
        self.init(computeMerkleRoot(&hashes, detectMutation: false).root)
    }
}

extension WitnessMerkleRoot {
    /// The witness merkle root of a block, and whether the tree is mutated.
    ///
    /// Equivalent to Bitcoin Core's `BlockWitnessMerkleRoot(block, &mutated)`. Pass every
    /// transaction's witness identifier in block order; the coinbase's is replaced with zero, as
    /// BIP 141 requires, so any value may be passed for it.
    ///
    /// Bitcoin Core ignores `isMutated` here: a duplicate in the witness tree means a duplicate
    /// transaction, which the transaction tree check already rejects.
    public static func compute(
        witnessTransactionIdentifiers: some Collection<WitnessTransactionIdentifier>
    ) -> (root: WitnessMerkleRoot, isMutated: Bool) {
        var hashes = witnessLeaves(witnessTransactionIdentifiers)
        let (root, isMutated) = computeMerkleRoot(&hashes, detectMutation: true)
        return (WitnessMerkleRoot(root), isMutated)
    }

    /// The witness merkle root of a block, without mutation detection. See
    /// `compute(witnessTransactionIdentifiers:)`.
    public init(witnessTransactionIdentifiers: some Collection<WitnessTransactionIdentifier>) {
        var hashes = witnessLeaves(witnessTransactionIdentifiers)
        self.init(computeMerkleRoot(&hashes, detectMutation: false).root)
    }

    /// The witness commitment a coinbase output carries after its `0x6a24aa21a9ed` prefix:
    /// `HASH256(witness root || witness reserved value)`.
    ///
    /// The witness reserved value is the coinbase input's single 32-byte witness item, usually zero.
    public func commitment(witnessReservedValue: Hash256) -> Hash256 {
        Hash256(hashingPair: hash, witnessReservedValue)
    }
}

/// Witness tree leaves: the coinbase's wtxid is defined as zero.
private func witnessLeaves(_ identifiers: some Collection<WitnessTransactionIdentifier>) -> [Hash256] {
    var hashes = identifiers.map(\.hash)
    if !hashes.isEmpty {
        hashes[0] = .zero
    }
    return hashes
}

/// Bitcoin Core's `ComputeMerkleRoot`: reduces `hashes` in place, one level at a time.
///
/// Per level: if requested, flag any pair of identical hashes (checked before the odd hash is
/// duplicated, so that duplication is never a mutation); pair an odd last hash with itself; hash
/// every pair. An empty list gives the all-zero hash.
///
/// Uses the storage of `hashes` as scratch space, so a root costs one allocation (the caller's
/// copy) plus two SHA-256 passes per node.
func computeMerkleRoot(_ hashes: inout [Hash256], detectMutation: Bool) -> (root: Hash256, isMutated: Bool) {
    guard !hashes.isEmpty else { return (.zero, false) }

    var isMutated = false
    var count = hashes.count
    var nodes = hashes.mutableSpan
    while count > 1 {
        if detectMutation {
            for left in stride(from: 0, to: count - 1, by: 2) where nodes[left] == nodes[left + 1] {
                isMutated = true
            }
        }
        // Core's SHA256D64 hashes a whole level in one batched call; this is the same step, one pair at a time.
        for parent in 0..<(count + 1) / 2 {
            let left = nodes[2 * parent]
            let right = 2 * parent + 1 < count ? nodes[2 * parent + 1] : left
            // Safe in place: `parent` never passes the pair it has just read.
            nodes[parent] = Hash256(hashingPair: left, right)
        }
        count = (count + 1) / 2
    }
    return (nodes[0], isMutated)
}

public func calculateMerkleRoot(_ txs: [Transaction]) -> MerkleRoot {
    // calculateMerkleRoot(txs.map(\.id))
    MerkleRoot(transactionIdentifiers: txs.map(\.id))
}

public func calculateMerkleRoot(_ hashes: [Data]) -> Data {
    precondition(!hashes.isEmpty)
    if hashes.count == 1 {
        return hashes[0]
    }
    let hashes =
        if hashes.count % 2 == 1 {
            hashes + [hashes[hashes.endIndex - 1]]
        } else {
            hashes
        }
    var nextHashes = [Data]()
    for i in stride(from: hashes.startIndex, to: hashes.endIndex, by: 2) {
        nextHashes.append(Data(SHA256d.hash(data: hashes[i] + hashes[i + 1])))
    }
    return calculateMerkleRoot(nextHashes)
}

public func calculateWitnessMerkleRoot(_ txs: [Transaction], addCoinbaseID: Bool = false) -> WitnessMerkleRoot {
    // calculateMerkleRoot((addCoinbaseID ? [Transaction.coinbaseWitnessID] : []) + txs.map(\.witnessID))
    WitnessMerkleRoot(
        witnessTransactionIdentifiers: (addCoinbaseID ? [Transaction.coinbaseWitnessID] : []) + txs.map(\.witnessID))
}
