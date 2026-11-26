public import protocol Crypto.HashFunction
public import struct Crypto.SHA256 // Internal

/// Bitcoin's `HASH160`: `RIPEMD160(SHA256(message))`.
///
/// ## Possible future improvement: one fewer allocation
///
/// `finalize()` copies the 32 SHA-256 bytes out through the digest's `Sequence`
/// conformance. swift-crypto's `Sequence` iterator is backed by a temporary
/// `Array`, so that costs one heap allocation per call (3 mallocs per HASH160
/// in total, versus 2 for SHA-256 alone).
///
/// CryptoKit in the macOS/iOS 27 SDKs exposes `Digest.bytes: RawSpan`, a
/// zero-copy view of the digest bytes. swift-crypto (5.2.0) does not. A
/// polyfill outside swift-crypto cannot provide it soundly, because the concrete
/// digests keep their bytes in an internal tuple and only hand out pointers that
/// are valid inside a closure.
///
/// If swift-crypto gains the same property, `finalize()` could become:
///
/// ```swift
/// public func finalize() -> Digest {
///     var ripemd160 = RIPEMD160()
///     ripemd160.update(bytes: sha256.finalize().bytes)  // no copy, no allocation
///     return ripemd160.finalize()
/// }
/// ```
///
/// This needs no `unsafe` in this package (the `RawSpan` entry point lives in
/// swift-crypto), removes the loop and the `InlineArray`, and saves the
/// allocation. It would not make HASH160 measurably faster: on a 33-byte input
/// (release, Apple silicon, p50 over three runs) the current safe version, which
/// uses the single-block `RIPEMD160.hash32` path, took 500-542 ns, identical to a
/// copy-free unsafe pass-through. Without `hash32` the safe version took about
/// 580-625 ns, so `hash32` is what keeps the safe code on par.
public struct Hash160: HashFunction, Sendable {
    public typealias Digest = RIPEMD160.Digest
    public static let blockByteCount = SHA256.blockByteCount

    private var sha256 = SHA256()

    public init() {}

    @unsafe
    public mutating func update(bufferPointer: UnsafeRawBufferPointer) {
        unsafe sha256.update(bufferPointer: bufferPointer)
    }

    public func finalize() -> Digest {
        // SAFE variant: copy the 32 digest bytes out through the Sequence API.
        var bytes = InlineArray<32, UInt8>(repeating: 0)
        var i = 0
        for byte in sha256.finalize() {
            bytes[i] = byte
            i &+= 1
        }

        // Optimization of `return RIPEMD160.hash(bytes: bytes.span.bytes)`
        return RIPEMD160.hash32(bytes.span)

    }
}
