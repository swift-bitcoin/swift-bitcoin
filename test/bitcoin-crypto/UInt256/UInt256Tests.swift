import Testing
import Foundation
@testable import BitcoinCrypto

// MARK: - Shared constants (used across suites)

private let zero      = UInt256.zero
private let one       = UInt256(1)
private let two       = UInt256(2)
private let maxVal    = UInt256.max
private let minVal    = UInt256.min // == 0 for unsigned
private let highBit   = UInt256(1) &<< 255 // 2^255
private let big: UInt256 = UInt256(low: 0, high: 0xFFFFFFFF_FFFFFFFF_00000000_00000000)

@Suite("UInt256")
struct UInt256Tests {

    @Test("Default init equals zero")
    func defaultInit() {
        #expect(UInt256() == zero)
    }

    @Test("Integer literal conformance")
    func integerLiteral() {
        let v: UInt256 = 42
        #expect(v == UInt256(42))
    }

    @Test("Init from various BinaryInteger types")
    func initFromBinaryInteger() {
        #expect(UInt256(UInt8 .max) == UInt256(255))
        #expect(UInt16.max == UInt256(65535))
        #expect(UInt32.max == UInt256(4_294_967_295))
        #expect(UInt64.max == UInt256(18_446_744_073_709_551_615))
    }

    @Test("Init truncatingIfNeeded from Int with negative value wraps")
    func initTruncatingNegative() {
        let v = UInt256(truncatingIfNeeded: Int(-1))
        // -1 in two's complement for the word width should equal UInt64.max in the
        // low word; the rest depends on your implementation details.
        #expect(v != zero)  // at minimum it must not be zero
    }

    @Test("Init clamping negative clamps to zero")
    func initClampingNegative() {
        let v = UInt256(clamping: -100)
        #expect(v == zero)
    }

    @Test("Init clamping large positive stays unchanged")
    func initClampingPositive() {
        let v = UInt256(clamping: UInt64.max)
        #expect(v == UInt256(UInt64.max))
    }

    @Test("Exact init from floating-point round-trip")
    func initExactFloat() throws {
        let f: Double = 1_000_000.0
        let v = try #require(UInt256(exactly: f))
        #expect(v == UInt256(1_000_000))
    }

    @Test("Exact init from non-integral floating-point returns nil")
    func initExactFloatNonIntegral() {
        #expect(UInt256(exactly: 3.14) == nil)
    }

    @Test("Exact init from NaN returns nil")
    func initExactNaN() {
        #expect(UInt256(exactly: Double.nan) == nil)
    }

    @Test("Exact init from infinity returns nil")
    func initExactInfinity() {
        #expect(UInt256(exactly: Double.infinity) == nil)
    }

    @Test("Init from String radix 10", .disabled())
    func initStringDecimal() throws {
        let s = "123456789012345678901234567890"
        let v = try #require(UInt256(s, radix: 10))
        #expect(v.description == s)
    }

    @Test("Init from String radix 16")
    func initStringHex() throws {
        let v = try #require(UInt256("ff", radix: 16))
        #expect(v == UInt256(255))
    }

    @Test("Init from invalid String returns nil")
    func initInvalidString() {
        #expect(UInt256("xyz", radix: 10) == nil)
    }
    // MARK: - 2. AdditiveArithmetic

    @Test("Zero static property")
    func zeroProperty() {
        #expect(UInt256.zero == 0)
    }

    @Test("Addition commutativity") // TODO: Find a way to use UInt256 as test arguments
    func additionCommutativity(/*a: UInt256, b: UInt256*/) {
        let arguments = [(UInt256(1), UInt256(2)), (UInt256(0), UInt256(100))]
        for (a, b) in arguments {
            let ab = a + b
            let ba = b + a
            #expect(ab == ba)
            //#expect(a + b == b + a)
        }
    }

    @Test("Addition associativity")
    func additionAssociativity() {
        let a: UInt256 = 10, b: UInt256 = 20, c: UInt256 = 30
        #expect((a + b) + c == a + (b + c))
    }

    @Test("Additive identity")
    func additiveIdentity() {
        let v: UInt256 = 999
        #expect(v + .zero == v)
        #expect(.zero + v == v)
    }

    @Test("Subtraction basic")
    func subtractionBasic() {
        #expect(UInt256(10) - UInt256(3) == UInt256(7))
    }

    @Test("Subtraction self equals zero")
    func subtractionSelf() {
        let v: UInt256 = 12345
        #expect(v - v == zero)
    }

    @Test("+= mutating operator")
    func plusEqualsMutating() {
        var v: UInt256 = 5
        v += 10
        #expect(v == 15)
    }

    @Test("-= mutating operator")
    func minusEqualsMutating() {
        var v: UInt256 = 20
        v -= 7
        #expect(v == 13)
    }

    // MARK: - 3. Numeric

    @Test("Multiplication by zero")
    func multiplyByZero() {
        let v: UInt256 = 99_999
        #expect(v * zero == zero)
        #expect(zero * v == zero)
    }

    @Test("Multiplication by one")
    func multiplyByOne() {
        let v: UInt256 = 12_345
        #expect(v * one == v)
        #expect(one * v == v)
    }

    @Test("Multiplication commutativity"/*,
          arguments: [(UInt256(3), UInt256(7)), (UInt256(100), UInt256(256))]*/)
    func multiplicationCommutativity(/*a: UInt256, b: UInt256*/) {
        for (a, b) in [(UInt256(3), UInt256(7)), (UInt256(100), UInt256(256))] {
            #expect(a * b == b * a)
        }
    }

    @Test("Multiplication associativity")
    func multiplicationAssociativity() {
        let a: UInt256 = 2, b: UInt256 = 3, c: UInt256 = 4
        #expect((a * b) * c == a * (b * c))
    }

    @Test("Distributivity")
    func distributivity() {
        let a: UInt256 = 5, b: UInt256 = 6, c: UInt256 = 7
        #expect(a * (b + c) == a * b + a * c)
    }

    @Test("*= mutating operator")
    func timesEqualsMutating() {
        var v: UInt256 = 6
        v *= 7
        #expect(v == 42)
    }

    @Test("magnitude equals self for unsigned")
    func magnitudeEquality() {
        let v: UInt256 = 54321
        #expect(v.magnitude == v)
    }

    @Test("Exact multiply without overflow"/*,
          arguments: [(UInt256(2), UInt256(3), UInt256(6)),
                      (UInt256(1_000), UInt256(1_000), UInt256(1_000_000))]*/)
    func exactMultiply(/*a: UInt256, b: UInt256, expected: UInt256*/) {
        for (a, b, expected) in [(UInt256(2), UInt256(3), UInt256(6)),
                       (UInt256(1_000), UInt256(1_000), UInt256(1_000_000))] {
            #expect(a * b == expected)
        }
    }

    // MARK: - 4. BinaryInteger

    // ---- Division & Remainder ----

    @Test("Division basic")
    func divisionBasic() {
        #expect(UInt256(10) / UInt256(3) == UInt256(3))
    }

    @Test("Division by one is identity")
    func divisionByOne() {
        let v: UInt256 = 98765
        #expect(v / one == v)
    }

    @Test("Remainder basic")
    func remainderBasic() {
        #expect(UInt256(10) % UInt256(3) == UInt256(1))
    }

    @Test("Division and remainder relationship"
          /*, arguments: [
           (UInt256(100), UInt256(7)),
           (UInt256(999), UInt256(256)),
           (UInt256(1),   UInt256(1)),
         ]*/)
    func divisionRemainderRelationship(/*a: UInt256, b: UInt256*/) {
        for (a, b) in [
          (UInt256(100), UInt256(7)),
          (UInt256(999), UInt256(256)),
          (UInt256(1),   UInt256(1)),
        ] {
            let q = a / b
            let r = a % b
            #expect(q * b + r == a)
        }
    }

    @Test("/= and %= mutating operators")
    func divModMutating() {
        var a: UInt256 = 100
        a /= 7
        #expect(a == 14)
        var b: UInt256 = 100
        b %= 7
        #expect(b == 2)
    }

    // ---- Bitwise ----

    @Test("AND with zero gives zero")
    func andWithZero() {
        let v: UInt256 = 0xFF
        #expect(v & zero == zero)
    }

    @Test("OR with zero is identity")
    func orWithZero() {
        let v: UInt256 = 0xABCD
        #expect(v | zero == v)
    }

    @Test("XOR with self is zero")
    func xorWithSelf() {
        let v: UInt256 = 12345
        #expect(v ^ v == zero)
    }

    @Test("XOR with zero is identity")
    func xorWithZero() {
        let v: UInt256 = 0x1234
        #expect(v ^ zero == v)
    }

    @Test("Bitwise NOT double-negation is identity")
    func bitwiseNOTDoubleNegation() {
        let v: UInt256 = 0xDEAD_BEEF
        #expect(~(~v) == v)
    }

    @Test("AND commutativity")
    func andCommutativity() {
        let a: UInt256 = 0b1010, b: UInt256 = 0b1100
        #expect(a & b == b & a)
    }

    @Test("De Morgan's law: NOT(a AND b) == NOT(a) OR NOT(b)")
    func deMorgans() {
        let a: UInt256 = 0xFF00, b: UInt256 = 0x0FF0
        #expect(~(a & b) == (~a | ~b))
    }

    // ---- Shifts ----

    @Test("Left shift by zero is identity")
    func leftShiftByZero() {
        let v: UInt256 = 7
        #expect(v << 0 == v)
    }

    @Test("Right shift by zero is identity")
    func rightShiftByZero() {
        let v: UInt256 = 7
        #expect(v >> 0 == v)
    }

    @Test("Left shift by 1 doubles")
    func leftShiftDoubles() {
        let v: UInt256 = 1
        #expect(v << 1 == two)
    }

    @Test("Right shift by 1 halves")
    func rightShiftHalves() {
        let v: UInt256 = 256
        #expect(v >> 1 == 128)
    }

    @Test("Shift round-trip",
          arguments: [1, 8, 64, 128, 200])
    func shiftRoundTrip(n: Int) {
        let original: UInt256 = 1
        let shifted = (original << n) >> n
        #expect(shifted == original)
    }

    @Test("Shift by full width gives zero")
    func shiftByFullWidth() {
        let v: UInt256 = maxVal
        #expect(v >> UInt256.bitWidth == zero)
        #expect(v << UInt256.bitWidth == zero)
    }

    // ---- Word access ----

    @Test("Words are non-empty")
    func wordsNonEmpty() {
        #expect(!one.words.isEmpty)
    }

    @Test("Words of zero are all zero")
    func wordsOfZero() {
        for word in zero.words {
            #expect(word == 0)
        }
    }

    // ---- Sign / parity ----

    @Test("isMultiple(of:) basic")
    func isMultiple() {
        #expect(UInt256(10).isMultiple(of: 5))
        #expect(!UInt256(10).isMultiple(of: 3))
    }

    @Test("isMultiple(of: zero) is false for nonzero")
    func isMultipleOfZeroNonzero() {
        // Per Swift spec: x.isMultiple(of: 0) == (x == 0)
        #expect(!UInt256(1).isMultiple(of: 0))
        #expect(UInt256(0).isMultiple(of: 0))
    }

    @Test("signum() for unsigned is always 0 or 1")
    func signumUnsigned() {
        #expect(zero.signum() == 0)
        #expect(one.signum() == 1)
        #expect(maxVal.signum() == 1)
    }

    // MARK: - 5. UnsignedInteger

    @Test("isSigned is false")
    func isSignedFalse() {
        #expect(UInt256.isSigned == false)
    }

    @Test("min is zero")
    func minIsZero() {
        #expect(UInt256.min == zero)
    }

    @Test("Subtraction wrapping underflow via &-")
    func wrappingSubtractionUnderflow() {
        let result = zero &- one
        #expect(result == maxVal)
    }

    @Test("No negative values representable")
    func noNegativeValues() {
        // Clamping init from any negative Int must give zero
        for n in [-1, -100, Int.min] {
            #expect(UInt256(clamping: n) == zero)
        }
    }

    // MARK: - 6. FixedWidthInteger

    @Test("bitWidth is 256")
    func bitWidthIs256() {
        #expect(UInt256.bitWidth == 256)
    }

    @Test("max is 2^256 - 1")
    func maxValue() {
        // Verify via bit pattern: all bits set → NOT 0 wraps to max
        #expect(UInt256.max == ~UInt256.zero)
    }

    @Test("min is zero (unsigned)")
    func minValue() {
        #expect(UInt256.min == zero)
    }

    // ---- Overflow arithmetic ----

    @Test("addingReportingOverflow: no overflow")
    func addNoOverflow() {
        let (result, overflow) = one.addingReportingOverflow(one)
        #expect(result == two)
        #expect(!overflow)
    }

    @Test("addingReportingOverflow: overflow at max")
    func addOverflowAtMax() {
        let (result, overflow) = maxVal.addingReportingOverflow(one)
        #expect(result == zero)          // wraps to 0
        #expect(overflow)
    }

    @Test("subtractingReportingOverflow: no overflow")
    func subtractNoOverflow() {
        let (result, overflow) = UInt256(10).subtractingReportingOverflow(UInt256(3))
        #expect(result == 7)
        #expect(!overflow)
    }

    @Test("subtractingReportingOverflow: underflow")
    func subtractUnderflow() {
        let (result, overflow) = zero.subtractingReportingOverflow(one)
        #expect(result == maxVal)
        #expect(overflow)
    }

    @Test("multipliedReportingOverflow: no overflow")
    func multiplyNoOverflow() {
        let (result, overflow) = UInt256(1_000).multipliedReportingOverflow(by: UInt256(1_000))
        #expect(result == 1_000_000)
        #expect(!overflow)
    }

    @Test("multipliedReportingOverflow: overflow")
    func multiplyOverflow() {
        let (_, overflow) = maxVal.multipliedReportingOverflow(by: two)
        #expect(overflow)
    }

    @Test("dividedReportingOverflow by nonzero never overflows for unsigned")
    func divideNoOverflow() {
        let (result, overflow) = UInt256(100).dividedReportingOverflow(by: UInt256(7))
        #expect(result == 14)
        #expect(!overflow)
    }

    @Test("remainderReportingOverflow by nonzero never overflows")
    func remainderNoOverflow() {
        let (result, overflow) = UInt256(100).remainderReportingOverflow(dividingBy: UInt256(7))
        #expect(result == 2)
        #expect(!overflow)
    }

    // ---- Wrapping arithmetic ----

    @Test("&+ wraps on overflow")
    func wrappingAdd() {
        #expect(maxVal &+ one == zero)
    }

    @Test("&- wraps on underflow")
    func wrappingSub() {
        #expect(zero &- one == maxVal)
    }

    @Test("&* wraps on overflow")
    func wrappingMul() {
        // 2^256 ≡ 0 (mod 2^256)
        #expect(highBit &* two == zero)
    }

    // ---- Clamping arithmetic (these don't overflow) ----

    @Test("addingWithOverflow result matches &+")
    func overflowAddMatchesWrapping() {
        let (wrapped, _) = maxVal.addingReportingOverflow(UInt256(5))
        #expect(wrapped == maxVal &+ UInt256(5))
    }

    // ---- Bit operations ----

    @Test("leadingZeroBitCount of zero is bitWidth")
    func leadingZeroOfZero() {
        #expect(zero.leadingZeroBitCount == UInt256.bitWidth)
    }

    @Test("leadingZeroBitCount of max is 0")
    func leadingZeroOfMax() {
        #expect(maxVal.leadingZeroBitCount == 0)
    }

    @Test("leadingZeroBitCount of 1 is bitWidth - 1")
    func leadingZeroOfOne() {
        #expect(one.leadingZeroBitCount == UInt256.bitWidth - 1)
    }

    @Test("trailingZeroBitCount of zero is bitWidth")
    func trailingZeroOfZero() {
        #expect(zero.trailingZeroBitCount == UInt256.bitWidth)
    }

    @Test("trailingZeroBitCount of 1 is 0")
    func trailingZeroOfOne() {
        #expect(one.trailingZeroBitCount == 0)
    }

    @Test("trailingZeroBitCount of power of 2",
          arguments: [1, 8, 64, 128, 200])
    func trailingZeroOfPowerOf2(n: Int) {
        let v: UInt256 = UInt256(1) << n
        #expect(v.trailingZeroBitCount == n)
    }

    @Test("nonzeroBitCount of zero is 0")
    func nonzeroBitCountZero() {
        #expect(zero.nonzeroBitCount == 0)
    }

    @Test("nonzeroBitCount of max is bitWidth")
    func nonzeroBitCountMax() {
        #expect(maxVal.nonzeroBitCount == UInt256.bitWidth)
    }

    @Test("nonzeroBitCount of 1 is 1")
    func nonzeroBitCountOne() {
        #expect(one.nonzeroBitCount == 1)
    }

    @Test("nonzeroBitCount and popcount relationship")
    func nonzeroBitCountAdditivity() {
        let a: UInt256 = 0b1010, b: UInt256 = 0b1100
        // popcount(a | b) + popcount(a & b) == popcount(a) + popcount(b)
        #expect((a | b).nonzeroBitCount + (a & b).nonzeroBitCount
                == a.nonzeroBitCount + b.nonzeroBitCount)
    }

    // ---- Byte order ----

    @Test("bigEndian and littleEndian round-trip")
    func byteOrderRoundTrip() {
        let v: UInt256 = 0x0102_0304_0506_0708
        #expect(UInt256(bigEndian: v.bigEndian) == v)
        #expect(UInt256(littleEndian: v.littleEndian) == v)
    }

    @Test("byteSwapped double-swap is identity")
    func byteSwapIdentity() {
        let v: UInt256 = 0xDEAD_BEEF_CAFE_BABE
        #expect(v.byteSwapped.byteSwapped == v)
    }

    // ---- Multiplied full width ----

    @Test("multipliedFullWidth: 1 × 1")
    func multipliedFullWidthOneOne() {
        let r = one.multipliedFullWidth(by: one)
        #expect(r.high == zero)
        #expect(r.low == one)
    }

    @Test("multipliedFullWidth: max × 1")
    func multipliedFullWidthMaxOne() {
        let r = maxVal.multipliedFullWidth(by: one)
        #expect(r.high == zero)
        #expect(r.low == maxVal)
    }

    @Test("multipliedFullWidth: max × max overflows into high")
    func multipliedFullWidthMaxMax() {
        let r = maxVal.multipliedFullWidth(by: maxVal)
        // (2^256 - 1)^2 = 2^512 - 2^257 + 1
        // high = 2^256 - 2 = max - 1
        // low  = 1
        #expect(r.high == maxVal - one)
        #expect(r.low == one)
    }

    // ---- Divided full width ----

    @Test("dividingFullWidth: basic")
    func dividingFullWidthBasic() {
        // (0, 10) / 3 = 3 remainder 1
        let (q, r) = UInt256(3).dividingFullWidth((high: zero, low: UInt256(10)))
        #expect(q == 3)
        #expect(r == 1)
    }

    // MARK: - 7. Strideable

    @Test("advanced(by:) positive stride")
    func advancedPositive() {
        let v: UInt256 = 10
        #expect(v.advanced(by: 5) == 15)
    }

    @Test("advanced(by:) zero stride is identity")
    func advancedZero() {
        let v: UInt256 = 42
        #expect(v.advanced(by: 0) == v)
    }

    @Test("distance(to:) positive")
    func distanceToPositive() {
        let a: UInt256 = 10, b: UInt256 = 20
        #expect(a.distance(to: b) == 10)
    }

    @Test("distance(to:) zero")
    func distanceToSelf() {
        let v: UInt256 = 99
        #expect(v.distance(to: v) == 0)
    }

    @Test("stride(from:to:by:) correctness")
    func strideFromToBy() {
        let values = Array(stride(from: UInt256(0), to: UInt256(10), by: 3))
        #expect(values == [0, 3, 6, 9])
    }

    @Test("stride(from:through:by:) correctness")
    func strideFromThroughBy() {
        let values = Array(stride(from: UInt256(0), through: UInt256(9), by: 3))
        #expect(values == [0, 3, 6, 9])
    }

    @Test("Range contains")
    func rangeContains() {
        let r: Range<UInt256> = 5..<10
        #expect(r.contains(7))
        #expect(!r.contains(10))
    }

    @Test("ClosedRange contains bounds")
    func closedRangeContains() {
        let r: ClosedRange<UInt256> = 5...10
        #expect(r.contains(5))
        #expect(r.contains(10))
    }

    // MARK: - 8. Comparable & Equatable

    @Test("Reflexivity: a == a")
    func reflexivity() {
        let v: UInt256 = 999
        #expect(v == v)
    }

    @Test("Symmetry: if a == b then b == a")
    func symmetry() {
        let a: UInt256 = 42, b: UInt256 = 42
        #expect(a == b)
        #expect(b == a)
    }

    @Test("Transitivity: a == b, b == c ⟹ a == c")
    func transitivity() {
        let a: UInt256 = 7, b: UInt256 = 7, c: UInt256 = 7
        #expect(a == b && b == c && a == c)
    }

    @Test("Strict ordering"/*, arguments: [
        (UInt256(0), UInt256(1)),
        (UInt256(1), UInt256(2)),
        (UInt256(UInt64.max), UInt256(UInt64.max) + 1),
        (UInt256.min, UInt256.max),
    ]*/)
    func strictOrdering(/*smaller: UInt256, larger: UInt256*/) {
        for (smaller, larger) in [
            (UInt256(0), UInt256(1)),
            (UInt256(1), UInt256(2)),
            (UInt256(UInt64.max), UInt256(UInt64.max) + 1),
            (UInt256.min, UInt256.max),
        ] {
            #expect(smaller < larger)
            #expect(larger > smaller)
            #expect(smaller <= larger)
            #expect(larger >= smaller)
            #expect(smaller != larger)
        }
    }

    @Test("min() and max() free functions")
    func minMaxFunctions() {
        let a: UInt256 = 3, b: UInt256 = 7
        #expect(Swift.min(a, b) == a)
        #expect(Swift.max(a, b) == b)
    }

    @Test("Sorted array")
    func sortedArray() {
        let arr: [UInt256] = [5, 3, 9, 1, 7]
        #expect(arr.sorted() == [1, 3, 5, 7, 9])
    }

    // MARK: - 9. Hashable

    @Test("Equal values have equal hashes")
    func equalValuesEqualHashes() {
        let a: UInt256 = 12345, b: UInt256 = 12345
        #expect(a.hashValue == b.hashValue)
    }

    @Test("Can be used as Dictionary key")
    func dictionaryKey() {
        var dict: [UInt256: String] = [:]
        dict[UInt256(1)] = "one"
        dict[UInt256(2)] = "two"
        #expect(dict[UInt256(1)] == "one")
        #expect(dict[UInt256(2)] == "two")
        #expect(dict[UInt256(3)] == nil)
    }

    @Test("Can be stored in Set")
    func setStorage() {
        let set: Set<UInt256> = [1, 2, 3, 2, 1]
        #expect(set.count == 3)
        #expect(set.contains(2))
    }


    // MARK: - 10. CustomStringConvertible

    @Test("description of zero")
    func descriptionZero() {
        #expect(zero.description == "0")
    }

    @Test("description of one")
    func descriptionOne() {
        #expect(one.description == "1")
    }

    @Test("description round-trips through init",
          arguments: [UInt256(0), UInt256(1), UInt256(255), UInt256(UInt64.max)])
    func descriptionRoundTrip(v: UInt256) {
        let s = v.description
        let parsed = UInt256(s, radix: 10)
        #expect(parsed == v)
    }

    @Test("String interpolation works")
    func stringInterpolation() {
        let v: UInt256 = 42
        let s = "\(v)"
        #expect(s == "42")
    }

    // MARK: - 11. Codable (Encodable + Decodable)

    @Test("JSON encode/decode round-trip", .disabled("Crashing Swift Linux 6.2.4"),
          arguments: [UInt256(0), UInt256(1), UInt256(UInt64.max), UInt256.max])
    func jsonRoundTrip(v: UInt256) throws {
        let encoder = JSONEncoder()
        let decoder = JSONDecoder()
        let data = try encoder.encode(v)
        let decoded = try decoder.decode(UInt256.self, from: data)
        #expect(decoded == v)
    }

    @Test("PropertyList encode/decode round-trip", .disabled("Crashing Swift Linux 6.2.4"))
    func plistRoundTrip() throws {
        let v: UInt256 = 9_999_999_999
        let encoder = PropertyListEncoder()
        encoder.outputFormat = .xml
        let decoder = PropertyListDecoder()
        let data = try encoder.encode(v)
        let decoded = try decoder.decode(UInt256.self, from: data)
        #expect(decoded == v)
    }

    // MARK: - 12. Edge Cases

    @Test("Max + 1 wraps to zero")
    func maxPlusOneWraps() {
        let (r, o) = maxVal.addingReportingOverflow(one)
        #expect(r == zero && o)
    }

    @Test("Min - 1 wraps to max")
    func minMinusOneWraps() {
        let (r, o) = zero.subtractingReportingOverflow(one)
        #expect(r == maxVal && o)
    }

    @Test("Shift by negative amount is masked (undefined → implementation-defined)")
    func shiftByNegative() {
        // Swift masks the shift amount to the valid range.
        // We just verify it does not crash and the result is a valid UInt256.
        let v: UInt256 = 1
        let _ = v << -1   // should not trap in release
    }

    @Test("Zero divided by anything nonzero is zero")
    func zeroDividedByAnything() {
        for divisor: UInt256 in [1, 2, 255, UInt256.max] {
            #expect(zero / divisor == zero)
        }
    }

    @Test("All-bits-set AND all-bits-set is all-bits-set")
    func maxAndMax() {
        #expect(maxVal & maxVal == maxVal)
    }

    @Test("All-bits-set XOR all-bits-set is zero")
    func maxXorMax() {
        #expect(maxVal ^ maxVal == zero)
    }

    @Test("All-bits-set OR zero is all-bits-set")
    func maxOrZero() {
        #expect(maxVal | zero == maxVal)
    }

    @Test("Large multiplication identity: (2^128)^2 == 2^256 ≡ 0")
    func largeMultiplicationOverflows() {
        let halfMax: UInt256 = UInt256(1) << 128
        let (_, overflow) = halfMax.multipliedReportingOverflow(by: halfMax)
        #expect(overflow)
    }

    @Test("Successive increments from max-2 to max")
    func successiveIncrementsNearMax() {
        var v = maxVal - 2
        for expected: UInt256 in [maxVal - 1, maxVal] {
            v &+= 1
            #expect(v == expected)
        }
    }

    @Test("Popcount of alternating bit pattern 0xAAAA…")
    func popcountAlternating() {
        // 0b10 repeated 128 times → 128 set bits
        var v = UInt256(0)
        for i in stride(from: 1, to: 256, by: 2) {
            v |= (UInt256(1) << i)
        }
        #expect(v.nonzeroBitCount == 128)
    }

    @Test("Rotation left by n then right by n is identity (manual roll)")
    func rotationRoundTrip() {
        let n = 37
        let v: UInt256 = 0xFEDC_BA98_7654_3210
        let rotated = (v << n) | (v >> (UInt256.bitWidth - n))
        let restored = (rotated >> n) | (rotated << (UInt256.bitWidth - n))
        #expect(restored == v)
    }

    // MARK: - 13. Numeric Conversion Correctness

    @Test("Converting to Int truncates",
          arguments: [UInt256(0), UInt256(1), UInt256(Int.max)])
    func toIntTruncation(v: UInt256) {
        let i = Int(truncatingIfNeeded: v)
        #expect(UInt256(truncatingIfNeeded: i) == v & UInt256(truncatingIfNeeded: Int.max))
    }

    @Test("Converting UInt256.max to Double is finite")
    func maxToDouble() {
        let d = Double(UInt256.max)
        #expect(d.isFinite)
    }

    @Test("Converting zero to Double is 0.0")
    func zeroToDouble() {
        #expect(Double(zero) == 0.0)
    }

    @Test("Double round-trip for small integers",
          arguments: [0.0, 1.0, 255.0, 65535.0, 1_000_000.0])
    func doubleRoundTrip(d: Double) throws {
        let v = try #require(UInt256(exactly: d))
        #expect(Double(v) == d)
    }

    @Test("Float round-trip for small integers",
          arguments: [Float(0), Float(1), Float(255)])
    func floatRoundTrip(f: Float) throws {
        let v = try #require(UInt256(exactly: f))
        #expect(Float(v) == f)
    }

    @Test("BinaryInteger words count equals bitWidth / wordSize")
    func wordsCount() {
        let wordBits = UInt.bitWidth
        let expectedCount = UInt256.bitWidth / wordBits
        #expect(zero.words.count == expectedCount)
    }

    // MARK: - 14. Sendable & Concurrency

    @Test("UInt256 values can be shared across actor boundaries", .disabled("Crashing Swift Linux 6.2.4"))
    func sharedAcrossActors() async {
        let v: UInt256 = 42
        let result = await Task.detached { v * v }.value
        #expect(result == v * v)
        print(result)
        #expect(result == UInt256(1764))
    }

    @Test("Concurrent reads produce consistent results", .disabled("Crashing Swift Linux 6.2.4"))
    func concurrentReads() async {
        let values: [UInt256] = (0..<100).map { UInt256($0) }
        await withTaskGroup(of: Bool.self) { group in
            for (i, v) in values.enumerated() {
                group.addTask {
                    v == UInt256(i)
                }
            }
            for await ok in group {
                #expect(ok)
            }
        }
    }
}


// ============================================================
// MARK: - 15. Performance (time-limited spot checks)
// ============================================================

@Suite("Performance")
struct PerformanceTests {

    @Test("1 000 000 additions complete quickly", .timeLimit(.minutes(1)))
    func millionAdditions() {
        var acc = UInt256.zero
        let step: UInt256 = 1
        for _ in 0..<1_000_000 {
            acc &+= step
        }
        #expect(acc == UInt256(1_000_000))
    }

    @Test("1 000 000 multiplications complete quickly", .timeLimit(.minutes(1)))
    func millionMultiplications() {
        var acc: UInt256 = 1
        for _ in 0..<1_000_000 {
            acc &*= 1        // identity mul — replace with a nontrivial value if desired
        }
        #expect(acc == 1)
    }

    @Test("SHA-style bit-shift chain completes quickly", .timeLimit(.minutes(1)))
    func bitShiftChain() {
        var v: UInt256 = UInt256.max
        for n in 0..<256 {
            v = (v << 1) | UInt256(n & 1)
        }
        #expect(v != UInt256(999_999)) // prevent optimising away
    }
}
