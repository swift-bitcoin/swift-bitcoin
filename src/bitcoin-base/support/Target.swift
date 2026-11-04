import BitcoinCrypto

/// A proof-of-work target: the 256-bit unsigned integer a block hash must not exceed.
///
/// Converts between every form Bitcoin uses for it:
///
/// | form       | example                          | API                              |
/// |------------|----------------------------------|----------------------------------|
/// | compact    | `0x1d00ffff` (header `nBits`)    | `init?(compact:)`, `compact`     |
/// | bits       | `"1d00ffff"` (RPC `bits`)        | `init?(bits:)`, `bits`           |
/// | difficulty | `1.0`                            | `init?(difficulty:)`, `difficulty` |
/// | hex        | `"0x00000000ffff0000…"`          | `init?(hex:)`, `hex`             |
/// | work       | `0x100010001` hashes             | `work`                           |
///
/// Compact and difficulty are lossy: compact keeps only the 3 most significant bytes, difficulty
/// only a `Double`'s 53 bits.
///
/// A target is never zero: no hash can meet it and it has no finite work. Every initializer
/// rejects it, and `value` is read-only so the invariant holds.
@frozen
public struct Target: Hashable, Comparable, Sendable, CustomStringConvertible {
    /// The value, stored little-endian like a block hash so the two compare directly.
    public private(set) var value: Hash256

    /// Wraps a 256-bit little-endian value, or returns `nil` if it is zero.
    public init?(_ value: Hash256) {
        guard !value.isZero else { return nil }
        self.value = value
    }

    /// For callers that have already ruled out zero.
    private init(nonZero value: Hash256) {
        self.value = value
    }

    /// Mainnet's difficulty-1 target, `0x00000000ffff0000…0000` (compact `0x1d00ffff`), which
    /// `difficulty` is measured against.
    public static let difficultyOne = Target(compact: 0x1D00_FFFF)!

    @inlinable
    public static func < (lhs: Self, rhs: Self) -> Bool {
        Hash256.numericallyPrecedes(lhs.value, rhs.value)
    }

    /// Hashes all 32 bytes. `Hash256` hashes only its first 8, which suits hash outputs, but
    /// targets aren't random: a compact target has just its top 2–3 bytes set, so those first 8
    /// bytes are zero for every target in a block header, and they would all share one bucket.
    @inlinable
    public func hash(into hasher: inout Hasher) {
        let words = value.words
        hasher.combine(words.low)
        hasher.combine(words.high)
    }

    public var description: String { hex }

    /// The expected number of hashes needed to meet this target.
    public var work: Chainwork { Chainwork(target: self) }
}

// MARK: - Compact (nBits)

extension Target {
    /// Decodes a compact target (a block header's `nBits`).
    ///
    /// Mirrors Bitcoin Core's `DeriveTarget`: returns `nil` for negative, zero or overflowing
    /// encodings, and for targets above `powLimit` when one is given. `nBits` is a 32-bit field,
    /// so a `bits` outside `0 ... 0xffff_ffff` is also `nil`.
    ///
    /// Decoding is safe without a limit; `powLimit` adds the consensus rule. Pass it for an
    /// `nBits` from a peer that hasn't been checked against the expected value. Leave it out for
    /// your own `getNextWorkRequired` output and for already-accepted headers, as when computing
    /// their work or difficulty. 
    public init?(compact bits: Int, powLimit: Target? = nil) {
        guard let bits = UInt32(exactly: bits) else { return nil }
        let exponent = Int(bits >> 24)
        var mantissa = bits & 0x007F_FFFF
        // A target is at most 3 mantissa bytes placed at byte offset `exponent - 3`.
        let offset: Int
        if exponent <= 3 {
            mantissa >>= 8 * (3 - exponent)
            offset = 0
        } else {
            offset = exponent - 3
        }

        let isNegative = mantissa != 0 && bits & 0x0080_0000 != 0
        let overflows = mantissa != 0
            && (exponent > 34 || (mantissa > 0xFF && exponent > 33) || (mantissa > 0xFFFF && exponent > 32))
        guard mantissa != 0, !isNegative, !overflows else { return nil }

        var bytes = InlineArray<32, UInt8>(repeating: 0)
        for k in 0..<3 where offset + k < 32 {
            bytes[offset + k] = UInt8(truncatingIfNeeded: mantissa >> (8 * k))
        }
        self.init(nonZero: Hash256(bytes))  // the guard above ruled out a zero mantissa

        if let powLimit, powLimit < self { return nil }
    }

    /// Encodes as a compact target, keeping the 3 most significant bytes and rounding down,
    /// like Bitcoin Core's `GetCompact`.
    ///
    /// Always below `0x2300_0000`, so it fits in 32 bits; serialize it with `UInt32(compact)`.
    public var compact: Int { Int(compactBits) }

    /// The compact encoding as the 32-bit value a header stores.
    var compactBits: UInt32 {
        let bytes = value.bytes
        var size = 32
        while size > 0, bytes[size - 1] == 0 { size -= 1 }

        func byte(_ index: Int) -> UInt32 { index >= 0 ? UInt32(bytes[index]) : 0 }
        var mantissa = byte(size - 1) << 16 | byte(size - 2) << 8 | byte(size - 3)
        // 0x00800000 is the sign bit, so a mantissa using it moves up a byte.
        if mantissa & 0x0080_0000 != 0 {
            mantissa >>= 8
            size += 1
        }
        return UInt32(size) << 24 | mantissa
    }
}

// MARK: - Bits (hex nBits)

extension Target {
    /// Parses a compact target written as hex, as RPC `bits` fields show it: `"1d00ffff"`.
    /// A `0x` prefix is accepted.
    public init?(bits: String) {
        guard let bytes = hexBytes(bits, byteCount: 4, zeroExtend: true) else { return nil }
        self.init(compact: bytes.reduce(0) { $0 << 8 | Int($1) })
    }

    /// The compact target as 8 lowercase hex digits, e.g. `"1d00ffff"`.
    public var bits: String { bigEndianBytes(compactBits).hex }
}

// MARK: - Difficulty

extension Target {
    /// How many times harder than `difficultyOne` this target is, as Bitcoin reports `difficulty`.
    public var difficulty: Double {
        Self.difficultyOne.doubleValue / doubleValue
    }

    /// The difficulty of a compact `nBits`, computed like Bitcoin Core's `GetDifficulty`.
    ///
    /// Core reads the 24-bit mantissa as unsigned and doesn't check the encoding, so this
    /// also gives a difficulty for an `nBits` that ``init(compact:powLimit:)`` rejects. Core's
    /// `blockchain_tests` vectors include three of them, such as `0x1cf88f6f`, whose mantissa has
    /// the sign bit set. For any `nBits` that decodes, the result equals ``difficulty`` up to
    /// floating-point rounding.
    ///
    /// Returns `nil` when `bits` is outside `0...0xffff_ffff`, or its mantissa is zero (Core
    /// divides by zero there and returns infinity).
    public static func difficulty(compact bits: Int) -> Double? {
        guard let bits = UInt32(exactly: bits), bits & 0x00ff_ffff != 0 else { return nil }
        var shift = Int(bits >> 24)
        var difficulty = Double(0x0000_ffff) / Double(bits & 0x00ff_ffff)
        while shift < 29 { difficulty *= 256; shift += 1 }
        while shift > 29 { difficulty /= 256; shift -= 1 }
        return difficulty
    }

    /// The target for a difficulty, rounded down. Returns `nil` unless `difficulty` is finite and
    /// positive and gives a target in 1 ... 2²⁵⁶ − 1.
    ///
    /// Only a `Double`'s 53 bits survive, so a compact target that goes through difficulty can come
    /// back one mantissa step lower (`0x1d00d86a` returns as `0x1d00d869`).
    public init?(difficulty: Double) {
        guard difficulty.isFinite, difficulty > 0 else { return nil }
        let value = (Self.difficultyOne.doubleValue / difficulty).rounded(.down)
        guard value >= 1, value <= 0x1p256 else { return nil }
        // A Double can't tell 2²⁵⁶ − 1 from 2²⁵⁶, so 2²⁵⁶ is the maximum target rounded up.
        guard value < 0x1p256 else {
            self.init(nonZero: Hash256(low: .max, high: .max))
            return
        }
        // Both steps are exact: the remainder is the bits below 2¹²⁸, the rest is a multiple of it.
        let low = value.truncatingRemainder(dividingBy: 0x1p128)
        self.init(nonZero: Hash256(low: UInt128(low), high: UInt128((value - low) / 0x1p128)))
    }

    private var doubleValue: Double {
        let words = value.words
        return Double(words.high) * 0x1p128 + Double(words.low)
    }
}

// MARK: - Hex

extension Target {
    /// Parses big-endian hex, most significant digit first: `"0x00000000ffff0000…"`.
    /// The `0x` prefix is optional and up to 64 digits are accepted, zero-extended on the left.
    /// Returns `nil` for zero.
    public init?(hex: String) {
        guard let displayOrder = hexBytes(hex, byteCount: Hash256.byteCount, zeroExtend: true) else { return nil }
        self.init(Hash256(displayOrder: displayOrder))
    }

    /// `"0x"` followed by 64 lowercase hex digits, most significant first.
    public var hex: String {
        "0x" + value.displayHex
    }
}

// MARK: - Big-endian bytes

extension Target {
    /// Creates a target from its 32 bytes in big-endian order, most significant first: the order
    /// Bitcoin Core writes `uint256` constants such as `consensus.powLimit`, and swift-bitcoin's
    /// `ConsensusParams.powLimit` stores. Accepts `[UInt8]`, `Data` and other byte collections.
    ///
    /// Returns `nil` unless there are exactly 32 bytes, or if the value is zero.
    public init?(bigEndianBytes bytes: some Collection<UInt8>) {
        let bytes = Array(bytes)
        guard bytes.count == Hash256.byteCount else { return nil }
        self.init(Hash256(displayOrder: bytes))
    }

    /// Creates a target from 32 bytes in big-endian order, most significant first, without
    /// allocating. Type the literal to select this overload; an untyped one is a `[UInt8]`:
    ///
    /// ```swift
    /// let bytes: InlineArray<32, UInt8> = [0x00, 0x00, 0x00, 0x00, 0xff, /* … */]
    /// let powLimit = Target(bigEndianBytes: bytes)
    /// ```
    ///
    /// Returns `nil` if the value is zero. `Target(Hash256(bytes))` reads an `InlineArray` the
    /// other way round, little-endian like a block hash in wire order.
    @inlinable
    public init?(bigEndianBytes bytes: InlineArray<32, UInt8>) {
        self.init(Hash256(InlineArray { bytes[Hash256.byteCount - 1 - $0] }))
    }
}

// MARK: - Retargeting

extension Target {
    /// The target for the next difficulty period, like Bitcoin Core's `CalculateNextWorkRequired`
    /// once it has chosen the period's blocks.
    ///
    /// Call it on the target of the period's last block (on testnet4, with BIP 94, its first
    /// block), with `actualTimespan` = the last block's time − the first block's time, in seconds.
    /// As in Core:
    /// 1. `actualTimespan` is clamped to `targetTimespan / 4 ... targetTimespan * 4`;
    /// 2. the new target is `self × actualTimespan ÷ targetTimespan`, rounded down;
    /// 3. it is capped at `powLimit`.
    ///
    /// Encode the result with `compact`, which rounds down to 3 significant bytes like Core's
    /// `GetCompact`.
    ///
    /// The arithmetic is Core's `arith_uint256`, bit for bit: the product `self × actualTimespan`
    /// wraps modulo 2²⁵⁶ before the division. With the mainnet, testnet4 and signet limits it
    /// never overflows, so this only matters for chains with a regtest-scale limit and retargeting
    /// turned on. There, Core's result (and so consensus) is the wrapped one, e.g. `0x207fffff` at
    /// 1.6× the timespan gives `0x1f6d386d`, not the limit.
    ///
    /// Returns `nil` if the new target is zero: a target below 4, or a wrapped product below
    /// `targetTimespan`. Core encodes that as compact 0, so `retargeted(…)?.compact ?? 0`
    /// reproduces it exactly.
    public func retargeted(actualTimespan: Int, targetTimespan: Int, powLimit: Target) -> Target? {
        precondition(targetTimespan > 0, "targetTimespan must be positive")
        let timespan = UInt64(min(max(actualTimespan, targetTimespan / 4), targetTimespan * 4))

        // self × timespan mod 2²⁵⁶, as four 64-bit limbs, least significant first. The final
        // carry is dropped, as arith_uint256's operator*= does.
        let words = value.words
        var limbs: InlineArray<4, UInt64> = [
            UInt64(truncatingIfNeeded: words.low), UInt64(truncatingIfNeeded: words.low >> 64),
            UInt64(truncatingIfNeeded: words.high), UInt64(truncatingIfNeeded: words.high >> 64),
        ]
        var carry: UInt64 = 0
        for i in limbs.indices {
            let (high, low) = limbs[i].multipliedFullWidth(by: timespan)
            let (sum, overflow) = low.addingReportingOverflow(carry)
            limbs[i] = sum
            carry = high &+ (overflow ? 1 : 0)  // high ≤ 2⁶⁴ − 2, so this can't wrap
        }

        // ÷ targetTimespan, by short division from the most significant limb.
        let divisor = UInt64(targetTimespan)
        var remainder: UInt64 = 0
        for i in limbs.indices.reversed() {
            (limbs[i], remainder) = divisor.dividingFullWidth((high: remainder, low: limbs[i]))
        }

        let low = UInt128(limbs[1]) << 64 | UInt128(limbs[0])
        let high = UInt128(limbs[3]) << 64 | UInt128(limbs[2])
        guard let new = Target(Hash256(low: low, high: high)) else { return nil }
        return min(new, powLimit)
    }
}
