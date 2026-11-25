// A pure Swift, memory-safe implementation of RIPEMD-160.
//
// Reference: H. Dobbertin, A. Bosselaers, B. Preneel,
// "RIPEMD-160: A Strengthened Version of RIPEMD" (1996),
// https://homes.esat.kuleuven.be/~bosselae/ripemd160.html
//
// No unsafe pointers are used by the algorithm itself: all data flows through
// `Span` / `InlineArray`, every access is bounds-checked, and there is
// no heap allocation while hashing. The only `unsafe` code is at the swift-crypto
// protocol boundary, whose requirements are spelled with `UnsafeRawBufferPointer`
// (`update(bufferPointer:)` here and `Digest.withUnsafeBytes`). The `RawSpan`
// entry points (`update(bytes:)`, `hash(bytes:)`) come from Crypto itself.

public import protocol Crypto.HashFunction

/// RACE Integrity Primitives Evaluation Message Digest, 160-bit variant.
///
/// ```swift
/// // One shot
/// let digest = RIPEMD160.hash(bytes: array.span)
///
/// // Incremental
/// var hasher = RIPEMD160()
/// hasher.update(bytes: chunk1.span)
/// hasher.update(bytes: chunk2.span)
/// let digest = hasher.finalize()
/// ```
///
/// - Important: RIPEMD-160 is not a general-purpose modern hash. Use it where a
///   protocol requires it (e.g. Bitcoin's `HASH160 = RIPEMD160(SHA256(x))`).
public struct RIPEMD160: HashFunction, Sendable {

    /// Size of a message block in bytes.
    public static let blockByteCount = 64

    /// Chaining value `h0...h4`.
    private var state: InlineArray<5, UInt32> = [0x6745_2301, 0xefcd_ab89, 0x98ba_dcfe, 0x1032_5476, 0xc3d2_e1f0]

    /// The partially filled block as little-endian words. Bytes at or beyond
    /// `bufferedCount` are always zero.
    private var buffer: InlineArray<16, UInt32> = .init(repeating: 0)

    /// Number of valid bytes in `buffer` (`0 ..< 64`).
    private var bufferedCount = 0

    /// Total message length in bytes, modulo 2⁶⁴.
    private var totalByteCount: UInt64 = 0

    /// Creates a new hasher.
    public init() {}

    // MARK: - Span API

    /// Absorbs `bytes` into the hash computation.
    ///
    /// Obtain a `Span<UInt8>` from any contiguous storage via `.span`
    /// (`Array`, `ContiguousArray`, `ArraySlice`, `Data`, `String.utf8Span`, …).
    public mutating func update(bytes: Span<UInt8>) {
        let count = bytes.count
        totalByteCount &+= UInt64(truncatingIfNeeded: count)
        var offset = 0

        // Top up a previously buffered partial block.
        if bufferedCount > 0 {
            let take = min(Self.blockByteCount - bufferedCount, count)
            for _ in 0..<take {
                append(bytes[offset])
                offset &+= 1
            }
            guard bufferedCount == Self.blockByteCount else { return }
            compressBuffer()
        }

        // Whole blocks straight from the input.
        while count &- offset >= Self.blockByteCount {
            let block = bytes.extracting(offset..<(offset &+ Self.blockByteCount))
            var words = InlineArray<16, UInt32>(repeating: 0)
            for i in 0..<16 {
                let j = i &* 4
                words[i] =
                    UInt32(block[j]) | UInt32(block[j &+ 1]) &<< 8
                    | UInt32(block[j &+ 2]) &<< 16 | UInt32(block[j &+ 3]) &<< 24
            }
            compress(words)
            offset &+= Self.blockByteCount
        }

        // Stash the tail.
        while offset < count {
            append(bytes[offset])
            offset &+= 1
        }
    }

    /// Returns the digest of everything absorbed so far. The hasher is not
    /// modified and may continue to be updated.
    public func finalize() -> Digest {
        var copy = self
        let bitCount = totalByteCount &<< 3  // length in bits, mod 2⁶⁴

        copy.append(0x80)
        if copy.bufferedCount > 56 {  // no room for the 8-byte length
            copy.compressBuffer()
        }
        copy.buffer[14] = UInt32(truncatingIfNeeded: bitCount)
        copy.buffer[15] = UInt32(truncatingIfNeeded: bitCount >> 32)
        copy.compressBuffer()
        return Digest(words: copy.state)
    }

    /// Hashes `bytes` in one call.
    public static func hash(bytes: Span<UInt8>) -> Digest {
        var hasher = RIPEMD160()
        hasher.update(bytes: bytes)
        return hasher.finalize()
    }

    /// Digest of exactly 32 bytes. The message plus padding always fits in a
    /// single block, so this skips the streaming buffer entirely.
    static func hash32(_ bytes: Span<UInt8>) -> Digest {
        precondition(bytes.count == 32, "hash32 requires exactly 32 bytes")
        var words = InlineArray<16, UInt32>(repeating: 0)
        for i in 0..<8 {
            let j = i &* 4
            words[i] =
                UInt32(bytes[j]) | UInt32(bytes[j &+ 1]) &<< 8
                | UInt32(bytes[j &+ 2]) &<< 16 | UInt32(bytes[j &+ 3]) &<< 24
        }
        words[8] = 0x80
        words[14] = 32 &* 8  // length in bits
        var hasher = RIPEMD160()
        hasher.compress(words)
        return Digest(words: hasher.state)
    }

    // MARK: - HashFunction conformance (the only unsafe boundary)

    /// `HashFunction` requirement. Immediately wrapped into a `RawSpan`.
    @unsafe
    public mutating func update(bufferPointer: UnsafeRawBufferPointer) {
        // `bufferPointer` is valid for the duration of this call and the span
        // does not escape it.
        let span = unsafe Span<UInt8>(_unsafeElements: bufferPointer.bindMemory(to: UInt8.self))
        update(bytes: span)
    }

    // MARK: - Internals

    @inline(__always)
    private mutating func append(_ byte: UInt8) {
        buffer[bufferedCount &>> 2] |= UInt32(byte) &<< UInt32((bufferedCount & 3) &<< 3)
        bufferedCount &+= 1
    }

    /// Compresses the buffered block (padding with zeros) and resets the buffer.
    private mutating func compressBuffer() {
        compress(buffer)
        buffer = .init(repeating: 0)
        bufferedCount = 0
    }

    @inline(__always) private static func rol(_ x: UInt32, _ n: UInt8) -> UInt32 {
        (x &<< UInt32(n)) | (x &>> (32 &- UInt32(n)))
    }

    /// The compression function. The left and right lines are independent, so
    /// they are interleaved step by step to give the CPU two dependency chains
    /// to overlap. Each round is instantiated with its own (inlined) boolean
    /// functions, so there is no per-step dispatch.
    private mutating func compress(_ x: InlineArray<16, UInt32>) {
        var al = state[0], bl = state[1], cl = state[2], dl = state[3], el = state[4]
        var ar = al, br = bl, cr = cl, dr = dl, er = el

        @inline(__always)
        func round(
            _ index: Int,
            _ fl: (UInt32, UInt32, UInt32) -> UInt32,
            _ fr: (UInt32, UInt32, UInt32) -> UInt32
        ) {
            let kl = Tables.constantsLeft[index], kr = Tables.constantsRight[index]
            let base = index &* 16
            for i in 0..<16 {
                let j = base &+ i
                let tl = Self.rol(al &+ fl(bl, cl, dl) &+ x[Int(Tables.wordsLeft[j])] &+ kl, Tables.shiftsLeft[j]) &+ el
                al = el; el = dl; dl = Self.rol(cl, 10); cl = bl; bl = tl

                let tr = Self.rol(ar &+ fr(br, cr, dr) &+ x[Int(Tables.wordsRight[j])] &+ kr, Tables.shiftsRight[j]) &+ er
                ar = er; er = dr; dr = Self.rol(cr, 10); cr = br; br = tr
            }
        }

        // Boolean functions f₀…f₄; the right line uses them in reverse order.
        @inline(__always) func f0(_ x: UInt32, _ y: UInt32, _ z: UInt32) -> UInt32 { x ^ y ^ z }
        @inline(__always) func f1(_ x: UInt32, _ y: UInt32, _ z: UInt32) -> UInt32 { (x & y) | (~x & z) }
        @inline(__always) func f2(_ x: UInt32, _ y: UInt32, _ z: UInt32) -> UInt32 { (x | ~y) ^ z }
        @inline(__always) func f3(_ x: UInt32, _ y: UInt32, _ z: UInt32) -> UInt32 { (x & z) | (y & ~z) }
        @inline(__always) func f4(_ x: UInt32, _ y: UInt32, _ z: UInt32) -> UInt32 { x ^ (y | ~z) }

        round(0, f0, f4)
        round(1, f1, f3)
        round(2, f2, f2)
        round(3, f3, f1)
        round(4, f4, f0)

        let t = state[1] &+ cl &+ dr
        state[1] = state[2] &+ dl &+ er
        state[2] = state[3] &+ el &+ ar
        state[3] = state[4] &+ al &+ br
        state[4] = state[0] &+ bl &+ cr
        state[0] = t
    }
}

// MARK: - Constants

private enum Tables {
    static let constantsLeft: InlineArray<5, UInt32> = [0x0000_0000, 0x5a82_7999, 0x6ed9_eba1, 0x8f1b_bcdc, 0xa953_fd4e]
    static let constantsRight: InlineArray<5, UInt32> = [0x50a2_8be6, 0x5c4d_d124, 0x6d70_3ef3, 0x7a6d_76e9, 0x0000_0000]

    /// Message word selection, left line (`r`).
    static let wordsLeft: InlineArray<80, UInt8> = [
        0, 1, 2, 3, 4, 5, 6, 7, 8, 9, 10, 11, 12, 13, 14, 15,
        7, 4, 13, 1, 10, 6, 15, 3, 12, 0, 9, 5, 2, 14, 11, 8,
        3, 10, 14, 4, 9, 15, 8, 1, 2, 7, 0, 6, 13, 11, 5, 12,
        1, 9, 11, 10, 0, 8, 12, 4, 13, 3, 7, 15, 14, 5, 6, 2,
        4, 0, 5, 9, 7, 12, 2, 10, 14, 1, 3, 8, 11, 6, 15, 13,
    ]

    /// Message word selection, right line (`r'`).
    static let wordsRight: InlineArray<80, UInt8> = [
        5, 14, 7, 0, 9, 2, 11, 4, 13, 6, 15, 8, 1, 10, 3, 12,
        6, 11, 3, 7, 0, 13, 5, 10, 14, 15, 8, 12, 4, 9, 1, 2,
        15, 5, 1, 3, 7, 14, 6, 9, 11, 8, 12, 2, 10, 0, 4, 13,
        8, 6, 4, 1, 3, 11, 15, 0, 5, 12, 2, 13, 9, 7, 10, 14,
        12, 15, 10, 4, 1, 5, 8, 7, 6, 2, 13, 14, 0, 3, 9, 11,
    ]

    /// Rotation amounts, left line (`s`).
    static let shiftsLeft: InlineArray<80, UInt8> = [
        11, 14, 15, 12, 5, 8, 7, 9, 11, 13, 14, 15, 6, 7, 9, 8,
        7, 6, 8, 13, 11, 9, 7, 15, 7, 12, 15, 9, 11, 7, 13, 12,
        11, 13, 6, 7, 14, 9, 13, 15, 14, 8, 13, 6, 5, 12, 7, 5,
        11, 12, 14, 15, 14, 15, 9, 8, 9, 14, 5, 6, 8, 6, 5, 12,
        9, 15, 5, 11, 6, 8, 13, 12, 5, 12, 13, 14, 11, 8, 5, 6,
    ]

    /// Rotation amounts, right line (`s'`).
    static let shiftsRight: InlineArray<80, UInt8> = [
        8, 9, 9, 11, 13, 15, 15, 5, 7, 7, 8, 11, 14, 14, 12, 6,
        9, 13, 15, 7, 12, 8, 9, 11, 7, 7, 12, 7, 6, 15, 13, 11,
        9, 7, 15, 11, 8, 6, 6, 14, 12, 13, 5, 14, 13, 13, 7, 5,
        15, 5, 8, 11, 14, 14, 6, 14, 6, 9, 12, 9, 12, 5, 15, 8,
        8, 5, 12, 9, 12, 5, 14, 6, 8, 13, 6, 5, 15, 13, 11, 11,
    ]
}
