// A pure Swift, memory-safe implementation of SipHash-2-4.
//
// Reference: J.-P. Aumasson and D. J. Bernstein, "SipHash: a fast short-input PRF" (2012),
// https://cr.yp.to/siphash/siphash-20120918.pdf
//
// No unsafe pointers are used by the algorithm itself: input flows through `Span<UInt8>`, the
// state is four plain `UInt64` stored properties, and nothing is allocated while hashing. The
// only `unsafe` code is at the swift-crypto protocol boundary, whose requirements are spelled
// with `UnsafeRawBufferPointer` (`update(bufferPointer:)` here and `Digest.withUnsafeBytes`).
// The `RawSpan` entry points (`update(bytes:)`, `hash(bytes:)`) come from Crypto itself.

public import protocol Crypto.HashFunction

/// SipHash-2-4: a keyed 64-bit pseudorandom function for short inputs (2 compression rounds,
/// 4 finalization rounds, 128-bit key).
///
/// ```swift
/// // From the 16 key bytes
/// var hasher = SipHash(key: keyBytes.span)!
/// hasher.update(bytes: message.span)
/// let tag = hasher.finalize().value        // UInt64
///
/// // One shot, with the key as two little-endian words
/// let digest = SipHash.hash(bytes: message.span, k0: k0, k1: k1)
/// ```
///
/// - Important: SipHash is a MAC/PRF for hash tables and short-input authentication (and BIP152
///   short transaction IDs). It is not a collision-resistant hash like SHA-256.
public struct SipHash: HashFunction, Sendable {

    /// Size of a message word in bytes.
    public static let blockByteCount = 8

    /// Number of compression rounds per message word (the `c` in SipHash-c-d).
    public static let c = 2

    /// Number of finalization rounds (the `d` in SipHash-c-d).
    public static let d = 4

    // Internal state, initialised from the key and the constant "somepseudorandomlygeneratedbytes".
    private var v0: UInt64
    private var v1: UInt64
    private var v2: UInt64
    private var v3: UInt64

    /// Trailing bytes (fewer than 8) not yet compressed, little-endian packed.
    private var pending: UInt64 = 0

    /// Number of valid bytes in `pending` (`0 ..< 8`).
    private var pendingByteCount = 0

    /// Message length modulo 256. SipHash only mixes in the low byte of the length.
    private var length: UInt8 = 0

    /// Creates a hasher with a random key.
    ///
    /// Required by `HashFunction`. Use `init(k0:k1:)` or `init(key:)` for reproducible output.
    public init() {
        self.init(k0: .random(in: .min ... .max), k1: .random(in: .min ... .max))
    }

    /// Creates a hasher from the key as two 64-bit words.
    ///
    /// `k0` is the little-endian interpretation of key bytes 0–7 and `k1` of bytes 8–15, as in the
    /// reference implementation.
    public init(k0: UInt64, k1: UInt64) {
        v0 = k0 ^ 0x736f_6d65_7073_6575
        v1 = k1 ^ 0x646f_7261_6e64_6f6d
        v2 = k0 ^ 0x6c79_6765_6e65_7261
        v3 = k1 ^ 0x7465_6462_7974_6573
    }

    /// Creates a hasher from a 16-byte key, or returns `nil` if `key` is not exactly 16 bytes.
    public init?(key: Span<UInt8>) {
        guard key.count == 16 else { return nil }
        self.init(k0: Self.word(key, 0), k1: Self.word(key, 8))
    }

    // MARK: - Span API

    /// Absorbs `bytes` into the hash computation.
    ///
    /// Obtain a `Span<UInt8>` from any contiguous storage via `.span`
    /// (`Array`, `ContiguousArray`, `ArraySlice`, `Data`, …).
    public mutating func update(bytes: Span<UInt8>) {
        let count = bytes.count
        length &+= UInt8(truncatingIfNeeded: count)
        var offset = 0

        // Complete a previously buffered partial word.
        if pendingByteCount > 0 {
            while pendingByteCount < 8 && offset < count {
                pending |= UInt64(bytes[offset]) &<< UInt64(pendingByteCount &<< 3)
                pendingByteCount &+= 1
                offset &+= 1
            }
            guard pendingByteCount == 8 else { return }
            compress(pending)
            pending = 0
            pendingByteCount = 0
        }

        // Whole words straight from the input.
        while count &- offset >= 8 {
            compress(Self.word(bytes, offset))
            offset &+= 8
        }

        // Stash the tail.
        while offset < count {
            pending |= UInt64(bytes[offset]) &<< UInt64(pendingByteCount &<< 3)
            pendingByteCount &+= 1
            offset &+= 1
        }
    }

    /// Returns the digest of everything absorbed so far. The hasher is not modified and may
    /// continue to be updated.
    public func finalize() -> Digest {
        var copy = self
        let last = pending | UInt64(length) &<< 56
        copy.compress(last)
        copy.v2 ^= 0xff
        copy.round()
        copy.round()
        copy.round()
        copy.round()
        return Digest(value: copy.v0 ^ copy.v1 ^ copy.v2 ^ copy.v3)
    }

    /// Hashes `bytes` under the key `(k0, k1)` in one call.
    public static func hash(bytes: Span<UInt8>, k0: UInt64, k1: UInt64) -> Digest {
        var hasher = SipHash(k0: k0, k1: k1)
        hasher.update(bytes: bytes)
        return hasher.finalize()
    }

    // MARK: - HashFunction conformance (the only unsafe boundary)

    /// `HashFunction` requirement. Immediately wrapped into a `Span`.
    @unsafe
    public mutating func update(bufferPointer: UnsafeRawBufferPointer) {
        // `bufferPointer` is valid for the duration of this call and the span does not escape it.
        let span = unsafe Span<UInt8>(_unsafeElements: bufferPointer.bindMemory(to: UInt8.self))
        update(bytes: span)
    }

    // MARK: - Internals

    /// Reads eight bytes at `offset` as a little-endian word. Bounds-checked.
    @inline(__always)
    private static func word(_ bytes: Span<UInt8>, _ offset: Int) -> UInt64 {
        let b = bytes.extracting(offset..<(offset &+ 8))
        return UInt64(b[0]) | UInt64(b[1]) &<< 8 | UInt64(b[2]) &<< 16 | UInt64(b[3]) &<< 24
            | UInt64(b[4]) &<< 32 | UInt64(b[5]) &<< 40 | UInt64(b[6]) &<< 48 | UInt64(b[7]) &<< 56
    }

    /// One word of input: `v3 ^= m; c rounds; v0 ^= m`.
    @inline(__always)
    private mutating func compress(_ m: UInt64) {
        v3 ^= m
        round()
        round()
        v0 ^= m
    }

    /// One SipRound.
    @inline(__always)
    private mutating func round() {
        v0 &+= v1
        v1 = (v1 &<< 13) | (v1 &>> 51)
        v1 ^= v0
        v0 = (v0 &<< 32) | (v0 &>> 32)
        v2 &+= v3
        v3 = (v3 &<< 16) | (v3 &>> 48)
        v3 ^= v2
        v0 &+= v3
        v3 = (v3 &<< 21) | (v3 &>> 43)
        v3 ^= v0
        v2 &+= v1
        v1 = (v1 &<< 17) | (v1 &>> 47)
        v1 ^= v2
        v2 = (v2 &<< 32) | (v2 &>> 32)
    }
}
