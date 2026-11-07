import BinaryParsing
import BitcoinCrypto

/// An unsigned 256-bit amount of proof-of-work: a single block's work, or a chain's cumulative work.
///
/// Stored as two `UInt128` words. Unlike digests, these are few and arithmetic-heavy, so the
/// 16-byte alignment costs nothing that matters here.
@frozen
public struct Chainwork: Hashable, Comparable, AdditiveArithmetic, Sendable, CustomStringConvertible {
    public var low: UInt128
    public var high: UInt128

    @inlinable
    public init(low: UInt128, high: UInt128 = 0) {
        self.low = low
        self.high = high
    }

    public static let zero = Chainwork(low: 0)

    /// The expected number of hashes to find a block hash at or below `target`: 2²⁵⁶ / (target + 1).
    ///
    /// Computed like Bitcoin Core's `GetBlockProof`, as `~target / (target + 1) + 1`, which avoids
    /// needing 2²⁵⁶ itself.
    public init(target: Target) {
        let words = target.value.words
        let target = Chainwork(low: words.low, high: words.high)
        // The maximum target: target + 1 would wrap to zero, and 2²⁵⁶ / 2²⁵⁶ is 1.
        guard target != ~.zero else {
            self = Chainwork(low: 1)
            return
        }
        self = (~target).dividedBy(target + Chainwork(low: 1)) + Chainwork(low: 1)
    }

    // MARK: Arithmetic (traps on overflow, like the standard integer types)

    @inlinable
    public static func + (lhs: Self, rhs: Self) -> Self {
        let (low, carry) = lhs.low.addingReportingOverflow(rhs.low)
        return Chainwork(low: low, high: lhs.high + rhs.high + (carry ? 1 : 0))
    }

    @inlinable
    public static func - (lhs: Self, rhs: Self) -> Self {
        let (low, borrow) = lhs.low.subtractingReportingOverflow(rhs.low)
        return Chainwork(low: low, high: lhs.high - rhs.high - (borrow ? 1 : 0))
    }

    @inlinable
    public static func < (lhs: Self, rhs: Self) -> Bool {
        (lhs.high, lhs.low) < (rhs.high, rhs.low)
    }

    /// 64 lowercase hex digits, most significant first, as Bitcoin Core prints `chainwork`.
    public var description: String {
        (bigEndianBytes(high) + bigEndianBytes(low)).hex
    }
}

// MARK: - Binary encoding

extension Chainwork: ExpressibleByParsing {
    public static let encodedByteCount = Hash256.byteCount

    /// Consumes 32 bytes: the value little-endian, least significant byte first, throwing if
    /// fewer remain.
    ///
    /// This is byte for byte what swift-bitcoin's `DifficultyTarget` writes (eight little-endian
    /// `UInt32` limbs, least significant first), so block-index records stored with it decode
    /// unchanged.
    @inlinable
    public init(parsing input: inout ParserSpan) throws(ParsingError) {
        let raw = try input.extract(byteCount: Self.encodedByteCount).bytes
        self.init(
            low: raw.load(fromByteOffset: 0, as: UInt128.self, .littleEndian),
            high: raw.load(fromByteOffset: 16, as: UInt128.self, .littleEndian))
    }

    /// Appends the 32-byte little-endian encoding. Traps if `output` has fewer than 32 bytes free.
    @inlinable
    public func encode(into output: inout OutputRawSpan) {
        output.append(low, as: UInt128.self, .littleEndian)
        output.append(high, as: UInt128.self, .littleEndian)
    }
}

// MARK: - Hex and big-endian bytes

extension Chainwork {
    /// Parses big-endian hex, most significant digit first: the form Bitcoin Core prints
    /// `chainwork` in and writes `nMinimumChainWork` constants in. The `0x` prefix is optional and
    /// 1 to 64 digits are accepted, zero-extended on the left. Unlike a target, zero is valid
    /// (regtest's minimum chain work is zero), but it has to be written: `""` and `"0x"` are `nil`.
    public init?(hex: String) {
        guard hex != "", hex != "0x", hex != "0X",
            let bytes = hexBytes(hex, byteCount: Hash256.byteCount, zeroExtend: true)
        else { return nil }
        self.init(bigEndianBytes: bytes)
    }

    /// Creates chain work from its 32 bytes, most significant first, as swift-bitcoin's
    /// `ConsensusParams` writes `minChainwork`. Accepts `[UInt8]`, `Data` and other byte
    /// collections. Returns `nil` unless there are exactly 32 bytes.
    public init?(bigEndianBytes bytes: some Collection<UInt8>) {
        let bytes = Array(bytes)
        guard bytes.count == Hash256.byteCount else { return nil }
        self.init(
            low: bytes[16..<32].reduce(0) { $0 << 8 | UInt128($1) },
            high: bytes[0..<16].reduce(0) { $0 << 8 | UInt128($1) })
    }

    /// Creates chain work from 32 bytes in big-endian order, most significant first, without
    /// allocating. Every 32-byte value is valid chain work, so this can't fail. Type the literal
    /// as `InlineArray<32, UInt8>` to select this overload; an untyped one is a `[UInt8]`.
    @inlinable
    public init(bigEndianBytes bytes: InlineArray<32, UInt8>) {
        let raw = bytes.span.bytes
        self.init(
            low: raw.load(fromByteOffset: 16, as: UInt128.self, .bigEndian),
            high: raw.load(fromByteOffset: 0, as: UInt128.self, .bigEndian))
    }
}

extension Chainwork {
    fileprivate static prefix func ~ (value: Self) -> Self {
        Chainwork(low: ~value.low, high: ~value.high)
    }

    fileprivate var leadingZeroBitCount: Int {
        high != 0 ? high.leadingZeroBitCount : 128 + low.leadingZeroBitCount
    }

    /// Shifts left by `shift` bits, 0 ..< 256. Smart shifts make the out-of-range word shifts zero.
    fileprivate func shiftedLeft(by shift: Int) -> Self {
        shift >= 128
            ? Chainwork(low: 0, high: low << (shift - 128))
            : Chainwork(low: low << shift, high: high << shift | low >> (128 - shift))
    }

    fileprivate func shiftedRightByOne() -> Self {
        Chainwork(low: low >> 1 | high << 127, high: high >> 1)
    }

    fileprivate mutating func setBit(_ bit: Int) {
        if bit >= 128 { high |= 1 << (bit - 128) } else { low |= 1 << bit }
    }

    /// Binary long division. It only loops over the bit-length difference, and real targets are
    /// large, so mainnet quotients take under 100 iterations.
    fileprivate func dividedBy(_ divisor: Self) -> Self {
        precondition(divisor != .zero, "Division by zero")
        let shift = divisor.leadingZeroBitCount - leadingZeroBitCount
        guard shift >= 0 else { return .zero }

        var remainder = self
        var shifted = divisor.shiftedLeft(by: shift)
        var quotient = Chainwork.zero
        for bit in stride(from: shift, through: 0, by: -1) {
            if remainder >= shifted {
                remainder = remainder - shifted
                quotient.setBit(bit)
            }
            shifted = shifted.shiftedRightByOne()
        }
        return quotient
    }
}

// MARK: - Equivalent time

extension Chainwork {
    /// How long, in seconds, the work between `from` and `to` would take to produce at the tip's
    /// difficulty: Bitcoin Core's `GetBlockProofEquivalentTime`.
    ///
    /// Computed as `|to − from| × targetSpacing ÷ tipTarget.work`, with Core's `arith_uint256`
    /// semantics: the product wraps modulo 2²⁵⁶ and the quotient rounds down. The result is
    /// negative when `to` has less work than `from`. A quotient that doesn't fit 63 bits
    /// saturates at `Int.max`, or `-Int.max` (not `Int.min`), as in Core.
    ///
    /// Taking the tip's ``Target`` rather than its work means the divisor is never zero, so this
    /// never traps on a valid target. Not a consensus rule: Core uses it for the `assumevalid`
    /// and stale-tip heuristics.
    ///
    /// - Parameters:
    ///   - to: The chain work at the later block, usually the best header.
    ///   - from: The chain work at the earlier block.
    ///   - tipTarget: The tip's target, whose work is the divisor.
    ///   - targetSpacing: The seconds between blocks, `nPowTargetSpacing`. Must not be negative.
    public static func blockProofEquivalentTime(
        to: Chainwork, from: Chainwork, tipTarget: Target, targetSpacing: Int
    ) -> Int {
        precondition(targetSpacing >= 0, "Negative target spacing")
        let (difference, sign) = to > from ? (to - from, 1) : (from - to, -1)
        let quotient =
            difference
            .multipliedWrapping(by: UInt64(targetSpacing))
            .dividedBy(tipTarget.work)
        guard quotient.high == 0, quotient.low <= UInt128(Int.max) else { return sign * Int.max }
        return sign * Int(quotient.low)
    }

    /// The product modulo 2²⁵⁶, like `arith_uint256`'s `*`.
    fileprivate func multipliedWrapping(by factor: UInt64) -> Self {
        let factor = UInt128(factor)
        let low = low.multipliedFullWidth(by: factor)
        return Chainwork(low: low.low, high: high &* factor &+ low.high)
    }
}

/// `value`'s bytes, most significant first, for hex encoding.
func bigEndianBytes<T: FixedWidthInteger>(_ value: T) -> [UInt8] {
    let size = T.bitWidth / 8
    return (0..<size).map { UInt8(truncatingIfNeeded: value >> (8 * (size - 1 - $0))) }
}
