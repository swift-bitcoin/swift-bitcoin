import Foundation

enum Arithmetic256 {

    static let bytes = 256 / 8
    static let width = 256 / 32

    static func isZero(_ a: [UInt32]) -> Bool {
        a.allSatisfy { $0 == 0 }
    }

    static func compare(_ a: [UInt32], to b: [UInt32]) -> Int {
        for i in (0 ..< width).reversed() {
            if a[i] < b[i] { return -1 }
            if a[i] > b[i] { return 1 }
        }
        return 0
    }

    static func assignTo(_ a: inout [UInt32], _ b: UInt64) {
        a[0] = UInt32(b)
        a[1] = UInt32(b >> 32)
        for i in 2 ..< width { a[i] = 0 }
    }

    static func shiftLeft(_ a: [UInt32], _ shift: Int) -> [UInt32] {
        var result = a
        for i in 0 ..< width { result[i] = 0 }
        let k = shift / 32
        let shift = shift % 32
        for i in 0 ..< width {
            if i + k + 1 < width && shift != 0 {
                result[i + k + 1] |= (a[i] >> (32 - shift))
            }
            if i + k < width {
                result[i + k] |= (a[i] << shift)
            }
        }
        return result
    }

    static func shiftRight(_ a: [UInt32], _ shift: Int) -> [UInt32] {
        var result = a
        for i in 0 ..< width { result[i] = 0 }
        let k = shift / 32
        let shift = shift % 32
        for i in 0 ..< width {
            if i - k - 1 >= 0 && shift != 0 {
                result[i - k - 1] |= (a[i] << (32 - shift))
            }
            if i - k >= 0 {
                result[i - k] |= (a[i] >> shift)
            }
        }
        return result
    }

    static func add(_ a: [UInt32], _ b64: UInt64) -> [UInt32] {
        var b = [UInt32](repeating: 0, count: width)
        assignTo(&b, b64)
        return add(a, b)
    }

    static func negate(_ a: [UInt32]) -> [UInt32] {
        var result = [UInt32](repeating: 0, count: width)
        for i in 0 ..< width {
            result[i] = ~a[i]
        }
        result = add(result, 1)
        return result
    }

    static func add(_ a: [UInt32], _ b: [UInt32]) -> [UInt32] {
        var result = a
        var carry = UInt64(0)
        for i in 0 ..< width {
            let n = carry + UInt64(a[i]) + UInt64(b[i])
            result[i] = UInt32(truncatingIfNeeded: n & 0xffffffff)
            carry = n >> 32
        }
        return result
    }

    static func substract(_ a: [UInt32], _ b: [UInt32]) -> [UInt32] {
        add(a, negate(b))
    }

    static func multiply(_ a: [UInt32], _ b32: UInt32) -> [UInt32] {
        var result = a
        var carry = UInt64(0)
        for i in 0 ..< width {
            let n = carry + UInt64(b32) * UInt64(result[i])
            result[i] = UInt32(n & 0xffffffff)
            carry = n >> 32
        }
        return result
    }

    static func divide(_ a: [UInt32], _ b: [UInt32]) -> [UInt32] {
        var div = b // make a copy, so we can shift.
        var num = a // make a copy, so we can subtract.
        var result = [UInt32](repeating: 0, count: width) // the quotient.
        let numBits = getBits(num)
        let divBits = getBits(div)
        if divBits == 0 {
            fatalError() // Division by zero
        }

        if divBits > numBits { // the result is certainly 0.
            return result
        }
        var shift = numBits - divBits
        div = shiftLeft(div, shift) // shift so that div and num align.
        while shift >= 0 {
            if compare(num, to: div) >= 0 {  // (num >= div) {
                num = substract(num, div) // num -= div
                result[shift / 32] |= (UInt32(1) << (shift & 31)) // set a bit of the result.
            }
            div = shiftRight(div, 1) // shift back.
            shift -= 1
        }
        // num now contains the remainder of the division.
        return result
    }

    // Returns the position of the highest bit set plus one, or zero if the value is zero.
    private static func getBits(_ a: [UInt32]) -> Int {
        for pos in (0 ..< width).reversed() {
            if a[pos] != 0 {
                for nBits in (1 ... 31).reversed() {
                    if (a[pos] & UInt32(1) << nBits) != 0 {
                        return 32 * pos + nBits + 1
                    }
                }
                return 32 * pos + 1
            }
        }
        return 0
    }

    private static func getLow64(_ n256: [UInt32]) -> UInt64 {
        UInt64(n256[0]) | UInt64(n256[1]) << 32
    }

    static func fromUInt64(_ value: UInt64) -> [UInt32] {
        var a = [UInt32](repeating: 0, count: width)
        Arithmetic256.assignTo(&a, value)
        return a
    }

    static func fromData(_ data: Data) -> [UInt32] {
        precondition(data.count == bytes)
        var data = data
        var result = [UInt32](repeating: 0, count: width)
        for i in 0 ..< width {
            result[i] = data.withUnsafeBytes { $0.loadUnaligned(as: UInt32.self) }
            data = data.dropFirst(MemoryLayout<UInt32>.size)
        }
        return result
    }

    static func toData(_ a: [UInt32]) -> Data {
        precondition(a.count == width)
        var data = Data(count: bytes)
        var offset = data.startIndex
        for i in 0 ..< width {
            offset = data.addBytes(a[i], at: offset)
        }
        return data
    }

    static func fromCompact(_ compact: Int) -> [UInt32] {
        var discardNegative = false
        var discardOverflow = false
        return fromCompact(compact, negative: &discardNegative, overflow: &discardOverflow)
    }

    /// This implementation directly uses shifts instead of going through an intermediate MPI representation.
    ///
    /// Also known as `SetCompact()`.
    ///
    static func fromCompact(_ compactInt: Int, negative: inout Bool, overflow: inout Bool) -> [UInt32] {
        let compact = UInt32(compactInt)
        var result = [UInt32](repeating: 0, count: width)
        let size = Int(compact >> 24)
        var word: UInt32 = compact & 0x007fffff
        if (size <= 3) {
            word >>= 8 * (3 - size)
            assignTo(&result, UInt64(word))
        } else {
            assignTo(&result, UInt64(word))
            result = shiftLeft(result, 8 * (size - 3))
        }
        negative = word != 0 && compact & 0x00800000 != 0
        overflow = word != 0 && ((size > 34) ||
                                 (word > 0xff && size > 33) ||
                                 (word > 0xffff && size > 32))
        return result
    }

    static func toCompact(_ a: [UInt32], negative: Bool = false) -> Int {
        var size = (getBits(a) + 7) / 8
        var compact = UInt32(0)
        if size <= 3 {
            compact = UInt32(truncatingIfNeeded: getLow64(a) << (8 * (3 - size)))
        } else {
            let bn: [UInt32] = shiftRight(a, 8 * (size - 3))
            compact = UInt32(truncatingIfNeeded: getLow64(bn))
        }
        // The 0x00800000 bit denotes the sign.
        // Thus, if it is already set, divide the mantissa by 256 and increase the exponent.
        if compact & 0x00800000 != 0 {
            compact >>= 8
            size += 1
        }
        assert((compact & ~UInt32(0x007fffff)) == 0)
        assert(size < 256)
        compact |= UInt32(size << 24)
        compact |= negative && (compact & 0x007fffff) != 0 ? 0x00800000 : 0
        return Int(compact)
    }
}
