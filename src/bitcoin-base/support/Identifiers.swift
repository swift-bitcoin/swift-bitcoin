import BitcoinCrypto

/// A transaction's identifier (txid): the double SHA-256 of its serialization without witness data.
@frozen
public struct TransactionIdentifier: Hash256Identifier {
    public var hash: Hash256

    @inlinable
    public init(_ hash: Hash256) {
        self.hash = hash
    }
}

/// A block's identifier: the double SHA-256 of its 80-byte header.
@frozen
public struct BlockHash: Hash256Identifier {
    public var hash: Hash256

    @inlinable
    public init(_ hash: Hash256) {
        self.hash = hash
    }
}

/// A transaction's witness identifier (wtxid): the double SHA-256 of its full serialization,
/// including witness data. Equal to the txid for transactions without witnesses.
@frozen
public struct WitnessTransactionIdentifier: Hash256Identifier {
    public var hash: Hash256

    @inlinable
    public init(_ hash: Hash256) {
        self.hash = hash
    }
}

/// The root of a block's transaction merkle tree, as committed to in its header.
///
/// See <doc:MerkleRoots> for computing and validating it.
@frozen
public struct MerkleRoot: Hash256Identifier {
    public var hash: Hash256

    @inlinable
    public init(_ hash: Hash256) {
        self.hash = hash
    }
}

/// The root of a block's witness merkle tree (BIP 141), committed to in its coinbase transaction.
///
/// See <doc:MerkleRoots> for computing and validating it.
@frozen
public struct WitnessMerkleRoot: Hash256Identifier {
    public var hash: Hash256

    @inlinable
    public init(_ hash: Hash256) {
        self.hash = hash
    }
}

// MARK: - Proof of work

extension BlockHash {
    /// Whether this hash satisfies `target`, i.e. `hash <= target` as 256-bit little-endian integers.
    @inlinable
    public func meetsTarget(_ target: Target) -> Bool {
        !Hash256.numericallyPrecedes(target.value, hash)
    }

    /// Bitcoin Core's `CheckProofOfWork`: decodes `bits` and checks this hash against it.
    @inlinable
    public func satisfiesProofOfWork(compact bits: UInt32, powLimit: Target) -> Bool {
        guard let target = Target(compact: bits, powLimit: powLimit) else { return false }
        return meetsTarget(target)
    }
}
