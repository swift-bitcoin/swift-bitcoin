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

/// `value`'s bytes, most significant first, for hex encoding.
func bigEndianBytes<T: FixedWidthInteger>(_ value: T) -> [UInt8] {
    let size = T.bitWidth / 8
    return (0..<size).map { UInt8(truncatingIfNeeded: value >> (8 * (size - 1 - $0))) }
}
