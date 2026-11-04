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
@frozen
public struct MerkleRoot: Hash256Identifier {
    public var hash: Hash256

    @inlinable
    public init(_ hash: Hash256) {
        self.hash = hash
    }
}

/// The root of a block's witness merkle tree (BIP 141), committed to in its coinbase transaction.
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
    ///
    /// Only compares: it doesn't check that `target` is allowed. Use it when you produced or
    /// already validated the target, for example when generating a block against your own
    /// `getNextWorkRequired`. For a header's `nBits` from a peer, use
    /// ``satisfiesProofOfWork(compact:powLimit:)``.
    @inlinable
    public func meetsTarget(_ target: Target) -> Bool {
        !Hash256.numericallyPrecedes(target.value, hash)
    }

    /// Bitcoin Core's `CheckProofOfWork`: decodes `bits` and checks this hash against it.
    ///
    /// Returns `false` if `bits` is negative, zero or overflows, if its target is above
    /// `powLimit`, or if this hash is above the target. It never traps, so it is safe on
    /// untrusted headers before anything else about them has been checked.
    ///
    /// Once a header's `bits` is known to equal the expected value, the `powLimit` check is
    /// implied, and ``meetsTarget(_:)`` against an already decoded target gives the same answer.
    @inlinable
    public func satisfiesProofOfWork(compact bits: Int, powLimit: Target) -> Bool {
        guard let target = Target(compact: bits, powLimit: powLimit) else { return false }
        return meetsTarget(target)
    }
}
