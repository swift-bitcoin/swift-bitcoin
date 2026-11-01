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

    public init?(compact bits: Int, powLimit: Target? = nil) {
        self.init(compact: UInt32(bits), powLimit: powLimit)
    }

    /// Decodes a compact target (a block header's `nBits`).
    ///
    /// Mirrors Bitcoin Core's `DeriveTarget`: returns `nil` for negative, zero or overflowing
    /// encodings, and for targets above `powLimit` when one is given.
    public init?(compact bits: UInt32, powLimit: Target? = nil) {
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
    public var compact: UInt32 {
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
        self.init(compact: bytes.reduce(0) { $0 << 8 | UInt32($1) })
    }

    /// The compact target as 8 lowercase hex digits, e.g. `"1d00ffff"`.
    public var bits: String { bigEndianBytes(compact).hex }
}

// MARK: - Difficulty

extension Target {
    /// How many times harder than `difficultyOne` this target is, as Bitcoin reports `difficulty`.
    public var difficulty: Double {
        Self.difficultyOne.doubleValue / doubleValue
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
