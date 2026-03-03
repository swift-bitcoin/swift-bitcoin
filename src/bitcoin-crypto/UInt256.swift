// MARK: - Memory layout

/// A 256-bit unsigned integer type.
@frozen
public struct UInt256: Sendable {
    @usableFromInline package var low: UInt128
    @usableFromInline package var high: UInt128

    @usableFromInline @_transparent
    package init(low: UInt128, high: UInt128) {
#if _endian(little)
        self.low = low
        self.high = high
#else
        self.low = high
        self.high = low
#endif
    }

    @_transparent
    public init(bitPattern: (Int128, Int128)) {
        self.init(low: UInt128(bitPattern: bitPattern.0), high: UInt128(bitPattern: bitPattern.1))
    }
}

// MARK: - Constants

extension UInt256 {
    @_transparent
    public static var zero: Self {
        Self(low: 0, high: 0)
    }

    @_transparent
    public static var min: Self { zero }

    @_transparent
    public static var max: Self {
        Self(low: .max, high: .max)
    }
}

// MARK: - Conversions from other integers

extension UInt256: ExpressibleByIntegerLiteral {

    public typealias IntegerLiteralType = UInt128

    @inlinable
    public init(integerLiteral value: IntegerLiteralType) {
        self.init(low: UInt128(value), high: 0)
    }

    @inlinable
    public init?<T>(exactly source: T) where T: BinaryInteger {
        guard let high = UInt128(exactly: source >> 128) else { return nil }
        let low = UInt128(truncatingIfNeeded: source)
        self.init(low: low, high: high)
    }

    @inlinable
    public init<T>(_ source: T) where T: BinaryInteger {
        guard let value = Self(exactly: source) else {
            fatalError("value cannot be converted to Self because it is outside the representable range")
        }
        self = value
    }

    @inlinable
    public init<T>(clamping source: T) where T: BinaryInteger {
        guard let value = Self(exactly: source) else {
            self = source < .zero ? .zero : .max
            return
        }
        self = value
    }

    @inlinable
    public init<T>(truncatingIfNeeded source: T) where T: BinaryInteger {
        let high = UInt128(truncatingIfNeeded: source >> 128)
        let low = UInt128(truncatingIfNeeded: source)
        self.init(low: low, high: high)
    }

    @inlinable
    public init<T>(_truncatingBits source: T) where T: BinaryInteger {
        self.init(T(truncatingIfNeeded: source))
    }
}

// MARK: - Conversions from Binary floating-point
extension UInt256 {
    @inlinable
    public init?<T>(exactly source: T) where T: BinaryFloatingPoint {
        let highAsFloat = (source * 0x1.0p-128).rounded(.towardZero)
        guard let high = UInt128(exactly: highAsFloat) else { return nil }
        guard let low = UInt128(
            exactly: high == 0 ? source : source - 0x1.0p128*highAsFloat
        ) else { return nil }
        self.init(low: low, high: high)
    }

    @inlinable
    public init<T>(_ source: T) where T: BinaryFloatingPoint {
        guard let value = Self(exactly: source.rounded(.towardZero)) else {
            fatalError("value cannot be converted to Self because it is outside the representable range")
        }
        self = value
    }
}

// MARK: - Non-arithmetic utility conformances
extension UInt256: Equatable {
    @inlinable
    public static func ==(a: Self, b: Self) -> Bool {
        a.low == b.low && a.high == b.high
    }
}

extension UInt256: Comparable {
    @inlinable
    public static func <(a: Self, b: Self) -> Bool {
        if a.high != b.high { return a.high < b.high }
        return a.low < b.low
    }
}

extension UInt256: Hashable {
    @inlinable
    public func hash(into hasher: inout Hasher) {
        hasher.combine(low)
        hasher.combine(high)
    }
}

extension UInt256: Codable {
    public func encode(to encoder: Encoder) throws {
        var container = encoder.unkeyedContainer()
        try container.encode(low)
        try container.encode(high)
    }

    public init(from decoder: Decoder) throws {
        var container = try decoder.unkeyedContainer()
        let low = try container.decode(UInt128.self)
        let high = try container.decode(UInt128.self)
        self.init(low: low, high: high)
    }
}

// MARK: - Overflow-reporting arithmetic

extension UInt256 {
    @inlinable
    public func addingReportingOverflow(
        _ other: Self
    ) -> (partialValue: Self, overflow: Bool) {
        addReportingOverflow(self, other)
    }

    @inlinable
    public func subtractingReportingOverflow(
        _ other: Self
    ) -> (partialValue: Self, overflow: Bool) {
        subReportingOverflow(self, other)
    }

    public func multipliedReportingOverflow(
        by other: Self
    ) -> (partialValue: Self, overflow: Bool) {
        mulReportingOverflow(self, other)
    }

    public func dividedReportingOverflow(
        by other: Self
    ) -> (partialValue: Self, overflow: Bool) {
        precondition(other != .zero, "Division by zero.")
        return (divReportingOverflow(self, other).partialValue, false)
    }

    public func remainderReportingOverflow(
        dividingBy other: Self
    ) -> (partialValue: Self, overflow: Bool) {
        precondition(other != .zero, "Remainder dividing by zero.")
        return (remReportingOverflow(self, other).partialValue, false)
    }
}

// MARK: - AdditiveArithmetic conformance

extension UInt256: AdditiveArithmetic {
    @inlinable
    public static func +(a: Self, b: Self) -> Self {
        let (result, overflow) = addReportingOverflow(a, b)
        // On arm64, this check materializes the carryout in register, then does
        // a TBNZ, where we should get a b.cs instead. I filed rdar://115387277
        // to track this, but it only costs us one extra instruction, so we'll
        // keep it as is for now.
        precondition(!overflow)
        return result
    }

    @inlinable
    public static func -(a: Self, b: Self) -> Self {
        let (result, overflow) = subReportingOverflow(a, b)
        precondition(!overflow)
        return result
    }

    @inlinable
    public static func &+(a: Self, b: Self) -> Self {
        addReportingOverflow(a, b).partialValue
    }

    @inlinable
    public static func &-(a: Self, b: Self) -> Self {
        subReportingOverflow(a, b).partialValue
    }

    @inlinable
    public static func &+=(a: inout Self, b: Self) { a = a &+ b }

    @inlinable
    public static func &-=(a: inout Self, b: Self) { a = a &- b }
}

// MARK: - Multiplication and division

extension UInt256{
    public static func *(a: Self, b: Self) -> Self {
        let (result, overflow) = mulReportingOverflow(a, b)
        precondition(!overflow)
        return result
    }

    @inlinable
    public static func *=(a: inout Self, b: Self) { a = a * b }

    public static func /(a: Self, b: Self) -> Self {
        return divReportingOverflow(a, b).partialValue
    }

    public static func /=(a: inout Self, b: Self) { a = a / b }

    public static func %(a: Self, b: Self) -> Self {
        return remReportingOverflow(a, b).partialValue
    }

    public static func %=(a: inout Self, b: Self) { a = a % b }
}

// MARK: - Numeric conformance

extension UInt256: Numeric {
    public typealias Magnitude = Self

    @inlinable
    public var magnitude: Self { self }
}

// MARK: - BinaryInteger conformance

extension UInt256: BinaryInteger {

    public struct Words {
        @usableFromInline
        let _value: UInt256
        @usableFromInline
        init(_value: UInt256) { self._value = _value }
    }

    @inlinable
    public var words: Words { Words(_value: self) }

    public static prefix func ~(a: Self) -> Self {
        return Self(low: ~a.low, high: ~a.high)
    }

    public static func &=(a: inout Self, b: Self) {
        a.low &= b.low
        a.high &= b.high
    }

    public static func |=(a: inout Self, b: Self) {
        a.low |= b.low
        a.high |= b.high
    }

    public static func ^=(a: inout Self, b: Self) {
        a.low ^= b.low
        a.high ^= b.high
    }

    public static func &>>=(a: inout Self, b: Self) {
        let masked = b & 255
        let shift = Int(masked)
        if shift == 0 { return }
        if shift < 128 {
            let carry = a.high << (128 - shift)
            a.low = (a.low >> shift) | carry
            a.high >>= shift
        } else if shift == 128 {
            a.low = a.high
            a.high = 0
        } else {
            a.low = a.high >> (shift - 128)
            a.high = 0
        }
    }

    public static func &<<=(a: inout Self, b: Self) {
        let masked = b & 255
        let shift = Int(masked)
        if shift == 0 { return }
        if shift < 128 {
            let carry = a.low >> (128 - shift)
            a.high = (a.high << shift) | carry
            a.low <<= shift
        } else if shift == 128 {
            a.high = a.low
            a.low = 0
        } else {
            a.high = a.low << (shift - 128)
            a.low = 0
        }
    }

    public var trailingZeroBitCount: Int {
        low == 0 ? 128 + high.trailingZeroBitCount : low.trailingZeroBitCount
    }
}

extension UInt256.Words: RandomAccessCollection {
    public typealias Element = UInt
    public typealias Index = Int
    public typealias SubSequence = Slice<Self>
    public typealias Indices = Range<Int>

    @inlinable public var count: Int { 256 / UInt.bitWidth }
    @inlinable public var startIndex: Int { 0 }
    @inlinable public var endIndex: Int { count }
    @inlinable public var indices: Indices { startIndex ..< endIndex }
    @inlinable public func index(after i: Int) -> Int { i + 1 }
    @inlinable public func index(before i: Int) -> Int { i - 1 }

    public subscript(position: Int) -> UInt {
        @inlinable
        get {
            precondition(position >= 0 && position < endIndex)
            return withUnsafeBytes(of: _value) {
                $0.assumingMemoryBound(to: UInt.self)[position]
            }
        }
    }
}

// MARK: - FixedWidthInteger conformance

extension UInt256: FixedWidthInteger, UnsignedInteger {

    @_transparent
    static public var bitWidth: Int { 256 }

    public var nonzeroBitCount: Int {
        high.nonzeroBitCount &+ low.nonzeroBitCount
    }

    public var leadingZeroBitCount: Int {
        high == 0 ? 128 + low.leadingZeroBitCount : high.leadingZeroBitCount
    }

    public var byteSwapped: Self {
        return Self(low: high.byteSwapped, high: low.byteSwapped)
    }
}

// MARK: - Private helpers replacing Builtin operations

fileprivate extension UInt256 {
    /// Returns true if the bit at the given index is 1.
    func bit(at index: Int) -> Bool {
        // Ensure index is within 0...255
        guard index >= 0 && index < 256 else { return false }

        if index < 128 {
            // Check the low 128 bits
            return (self.low & (1 << index)) != 0
        } else {
            // Check the high 128 bits (offset the index by 128)
            return (self.high & (1 << (index - 128))) != 0
        }
    }

    /// Sets the bit at the given index to 1.
    mutating func setBit(at index: Int) {
        guard index >= 0 && index < 256 else { return }

        if index < 128 {
            self.low |= (1 << index)
        } else {
            self.high |= (1 << (index - 128))
        }
    }
}


@usableFromInline internal func addReportingOverflow(_ a: UInt256, _ b: UInt256) -> (partialValue: UInt256, overflow: Bool) {
    // 1. Add the low parts and check for overflow (the carry)
    let (lowSum, lowOverflow) = a.low.addingReportingOverflow(b.low)

    // 2. Add the high parts
    let (highSum, highOverflow1) = a.high.addingReportingOverflow(b.high)

    // 3. Add the carry from the low addition to the high sum
    let carry: UInt128 = lowOverflow ? 1 : 0
    let (finalHighSum, highOverflow2) = highSum.addingReportingOverflow(carry)

    // 4. Return the combined result.
    // Overflow occurs if high addition overflowed at either step.
    return (
        partialValue: UInt256(low: lowSum, high: finalHighSum),
        overflow: highOverflow1 || highOverflow2
    )
    /*
     let (low, carryLow) = a.low.addingReportingOverflow(b.low)
     let (highTemp, carryHigh1) = a.high.addingReportingOverflow(b.high)
     let (high, carryHigh2) = highTemp.addingReportingOverflow(carryLow ? 1 : 0)
     let overflow = carryHigh1 || carryHigh2
     return (UInt256(low: low, high: high), overflow)*/
}



@usableFromInline internal func subReportingOverflow(_ a: UInt256, _ b: UInt256) -> (partialValue: UInt256, overflow: Bool) {
    let (low, borrowLow) = a.low.subtractingReportingOverflow(b.low)
    let borrow = borrowLow ? 1 : 0
    let (highTemp, borrowHigh1) = a.high.subtractingReportingOverflow(b.high)
    let (high, borrowHigh2) = highTemp.subtractingReportingOverflow(UInt128(borrow))
    let overflow = borrowHigh1 || borrowHigh2
    return (UInt256(low: low, high: high), overflow)
}

@usableFromInline internal func mulReportingOverflow(_ a: UInt256, _ b: UInt256) -> (partialValue: UInt256, overflow: Bool) {
    // (self.high * 2^128 + self.low) * (other.high * 2^128 + other.low)
    // Expansion:
    // 1. self.low * other.low (Can contribute to low and high 128 bits)
    // 2. self.low * other.high (Can contribute to high 128 bits and overflow)
    // 3. self.high * other.low (Can contribute to high 128 bits and overflow)
    // 4. self.high * other.high (Always overflows 256 bits unless one is zero)

    // Part 1: Lowest product (al * bl)
    // Swift's multipliedFullWidth returns (high, low)
    let (lowHighCarry, lowLow) = a.low.multipliedFullWidth(by: b.low)

    // Part 2: Middle products (al * bh) and (ah * bl)
    let (mid1, mid1Overflow) = a.low.multipliedReportingOverflow(by: b.high)
    let (mid2, mid2Overflow) = a.high.multipliedReportingOverflow(by: b.low)

    // Part 3: Combine high parts
    // Start with the carry from the lowest product
    var highPart = lowHighCarry
    var overflow = false

    // Add middle products to the high part
    let (h1, o1) = highPart.addingReportingOverflow(mid1)
    let (h2, o2) = h1.addingReportingOverflow(mid2)

    highPart = h2

    // Part 4: Determine Overflow
    // Overflow occurs if:
    // - self.high * other.high > 0
    // - Any intermediate multiplication of high parts overflowed
    // - Any intermediate addition to the highPart overflowed
    let highHighOverflow = (a.high != 0 && b.high != 0)
    overflow = highHighOverflow || mid1Overflow || mid2Overflow || o1 || o2

    return (
        partialValue: UInt256(low: lowLow, high: highPart),
        overflow: overflow
    )
}

// 1. Division
@usableFromInline internal func divReportingOverflow(_ dividend: UInt256, _ divisor: UInt256) -> (partialValue: UInt256, overflow: Bool) {
    // Division by zero is the only overflow case for unsigned integers
    if divisor == 0 {
        return (dividend, true)
    }
    if divisor > dividend {
        return (UInt256.zero, false)
    }

    let (q, _) = longDivide(dividend, divisor)
    return (q, false)
}

// 2. Remainder
@usableFromInline internal func remReportingOverflow(_ dividend: UInt256, _ divisor: UInt256) -> (partialValue: UInt256, overflow: Bool) {
    if divisor == 0 {
        return (dividend, true)
    }
    if divisor > dividend {
        return (dividend, false)
    }

    let (_, r) = longDivide(dividend, divisor)
    return (r, false)
}

// Helper: Binary Long Division Algorithm
private func longDivide(_ dividend: UInt256, _ divisor: UInt256) -> (quotient: UInt256, remainder: UInt256) {
    var quotient = UInt256.zero
    var remainder = UInt256.zero

    // Iterate from most significant bit down to 0
    for i in (0...255).reversed() {
        // Left shift remainder by 1 and bring down the i-th bit of dividend
        remainder = remainder << 1
        if dividend.bit(at: i) {
            remainder.low |= 1
        }

        // If remainder >= divisor, subtract divisor and set quotient bit
        if remainder >= divisor {
            remainder = remainder.subtractingReportingOverflow(divisor).partialValue
            quotient.setBit(at: i)
        }
    }
    return (quotient, remainder)
}

// MARK: - Unused implementations (may not be 100% correct)

@usableFromInline internal func mulReportingOverflow2(_ a: UInt256, _ b: UInt256) -> (partialValue: UInt256, overflow: Bool) {

    // Karatsuba multiplication using 128-bit halves
    // a = (ah, al), b = (bh, bl)
    let al = a.low
    let ah = a.high
    let bl = b.low
    let bh = b.high

    // p0 = al * bl (256-bit)
    // let p0_lo = al &* bl
    // Helper: full 256-bit product of two UInt128 as (lo, hi)
    @inline(__always)
    func fullMul128(_ x: UInt128, _ y: UInt128) -> (lo: UInt128, hi: UInt128) {
        // Split operands into 64-bit halves within 128-bit to compute hi accurately using only UInt128 ops
        let x0 = x & ((UInt128(1) << 64) &- 1)
        let x1 = x >> 64
        let y0 = y & ((UInt128(1) << 64) &- 1)
        let y1 = y >> 64

        let p00 = x0 &* y0                  // 128-bit
        let p01 = x0 &* y1                  // 128-bit
        let p10 = x1 &* y0                  // 128-bit
        let p11 = x1 &* y1                  // 128-bit

        // Combine: (p11 << 128) + ((p01 + p10) << 64) + p00
        var lo = p00
        var hi: UInt128 = 0

        // Add (p01 + p10) << 64
        let cross = p01 &+ p10
        let crossCarry = cross < p01
        let crossLoShift = cross << 64
        lo &+= crossLoShift
        let carry = lo < crossLoShift

        // hi collects: p11 + (p01>>64 + p10>>64) + carries
        hi &+= p11
        hi &+= (p01 >> 64)
        hi &+= (p10 >> 64)
        if crossCarry { hi &+= 1 }
        if carry { hi &+= 1 }

        // Also add upper 64 of p00 into hi (p00 >> 128 is zero; but (p00 >> 64) contributes when shifting cross terms)
        hi &+= (p00 >> 128) // zero, kept for clarity

        return (lo, hi)
    }

    let (p0lo, p0hi) = fullMul128(al, bl)

    // p2 = ah * bh
    let (p2lo, p2hi) = fullMul128(ah, bh)

    // m = (ah - al) * (bl - bh) with sign tracking
    let (d1, neg1) = ah >= al ? (ah &- al, false) : (al &- ah, true)
    let (d2, neg2) = bl >= bh ? (bl &- bh, false) : (bh &- bl, true)
    let (mlo, mhi) = fullMul128(d1, d2)
    let mIsNegative = (neg1 != neg2)

    // p1 = p0 + p2 - m  (as 256-bit). We'll compute p1_hi only, since p1_lo contributes into the middle 128 bits.
    // Start from p0 + p2
    var p1_lo = p0lo
    var p1_hi = p0hi
    var c: Bool
    (p1_lo, c) = p1_lo.addingReportingOverflow(p2lo)
    if c { p1_hi &+= 1 }
    p1_hi &+= p2hi

    // Subtract m (signed): if m negative, add; else subtract.
    if mIsNegative {
        // p1 += m
        (p1_lo, c) = p1_lo.addingReportingOverflow(mlo)
        if c { p1_hi &+= 1 }
        p1_hi &+= mhi
    } else {
        // p1 -= m
        let (newLo, borrowLo) = p1_lo.subtractingReportingOverflow(mlo)
        p1_lo = newLo
        p1_hi &-= mhi
        if borrowLo { p1_hi &-= 1 }
    }

    // Result is: low = p0lo, high = p0hi + p1
    var resLow = p0lo
    var resHigh = p0hi
    (resLow, c) = resLow.addingReportingOverflow(0) // no-op; kept for symmetry
    (resHigh, c) = resHigh.addingReportingOverflow(p1_lo)
    // carry c from adding p1_lo goes into upper 128 beyond resHigh; accumulate into p1_hi
    var finalHigh = p1_hi
    if c { finalHigh &+= 1 }

    finalHigh &+= resHigh // accumulate middle into top

    let result = UInt256(low: resLow, high: finalHigh)
    return (result, false)
}

@usableFromInline internal func divReportingOverflow2(_ a: UInt256, _ b: UInt256) -> (partialValue: UInt256, overflow: Bool) {
    let (q, _) = divRem(a, b)
    return (q, false)
}

@usableFromInline internal func remReportingOverflow2(_ a: UInt256, _ b: UInt256) -> (partialValue: UInt256, overflow: Bool) {
    let (_, r) = divRem(a, b)
    return (r, false)
}

@usableFromInline internal func divRem(_ a: UInt256, _ b: UInt256) -> (q: UInt256, r: UInt256) {
    precondition(b != .zero, "Division by zero.")
    var dividend = a
    var divisor = b
    var quotient = UInt256.zero
    var remainder = UInt256.zero

    // Compute the shift difference between dividend and divisor
    let dividendLZ = dividend.leadingZeroBitCount
    let divisorLZ = divisor.leadingZeroBitCount
    var shift = dividendLZ - divisorLZ
    if shift < 0 { shift = 0 }

    divisor &<<= UInt256(shift)
    var s = shift

    while s >= 0 {
        if dividend >= divisor {
            dividend &-= divisor
            // Set the bit at position s in quotient
            if s < 128 {
                quotient.low |= UInt128(1) << UInt128(s)
            } else {
                quotient.high |= UInt128(1) << UInt128(s - 128)
            }
        }
        divisor &>>= UInt256(1)
        s -= 1
    }
    remainder = dividend
    return (quotient, remainder)
}
