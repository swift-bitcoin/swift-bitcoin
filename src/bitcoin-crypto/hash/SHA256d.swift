public import protocol Crypto.HashFunction
public import struct Crypto.SHA256

/// Bitcoin's `HASH256`: `SHA256(SHA256(message))`.
///
/// A streaming `HashFunction` whose `Digest` is the ordinary `SHA256.Digest`.
public struct SHA256d: HashFunction, Sendable {
    public typealias Digest = SHA256.Digest
    public static let blockByteCount = SHA256.blockByteCount

    private var sha256 = SHA256()

    public init() {}

    @unsafe
    public mutating func update(bufferPointer: UnsafeRawBufferPointer) {
        unsafe sha256.update(bufferPointer: bufferPointer)
    }

    public mutating func update(bytes: RawSpan) {
        sha256.update(bytes: bytes)
    }

    public func finalize() -> Digest {
        Self.finishing(sha256)
    }

    /// Completes a double hash: finalizes `firstPass` and hashes the resulting 32 bytes again.
    ///
    /// Use this when the first pass was driven by a plain `SHA256` hasher.
    public static func finishing(_ firstPass: SHA256) -> Digest {
        let inner = firstPass.finalize().copiedBytes
        var outer = SHA256()
        outer.update(bytes: inner.span.bytes)
        return outer.finalize()
    }

    /// Hashes the 64-byte concatenation `left || right` twice, as done for every inner node of a
    /// Bitcoin Merkle tree.
    public static func hash(pairing left: InlineArray<32, UInt8>, _ right: InlineArray<32, UInt8>) -> Digest {
        var first = SHA256()
        first.update(bytes: left.span.bytes)
        first.update(bytes: right.span.bytes)
        return finishing(first)
    }
}
