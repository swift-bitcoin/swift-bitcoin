import Foundation

enum Arithmetic256 {

    static let bytes = 256 / 8
    static let width = 256 / 32

    static func isZero(_ a: [UInt32]) -> Bool {
        a.allSatisfy { $0 == 0 }
    }

    static func compare(_ a: [UInt32], to b: [UInt32]) -> Int {
        for i in (0 ..< width).reversed() {
            if a[i] < b[i] {
                return -1
            }
            if a[i] > b[i] {
                return 1
            }
        }
        return 0
    }

    static func assignTo(_ pn: inout [UInt32], _ b: UInt64) {
        pn[0] = UInt32(b)
        pn[1] = UInt32(b >> 32)
        for i in 2 ..< width {
            pn[i] = 0
        }
    }

    static func shiftLeft(_ a: [UInt32], shift: UInt32) -> [UInt32] {
        var pn = a
        for i in 0 ..< width {
            pn[i] = 0
        }
        let k = Int(shift / 32)
        let shift = shift % 32
        for i in 0 ..< width {
            if i + k + 1 < width && shift != 0 {
                pn[i + k + 1] |= (a[i] >> (32 - shift))
            }
            if i + k < width {
                pn[i + k] |= (a[i] << shift)
            }
        }
        return pn
    }

    static func shiftRight(_ a: [UInt32], shift: UInt32) -> [UInt32] {
        var pn = a
        for i in 0 ..< width {
            pn[i] = 0
        }
        let k = Int(shift / 32)
        let shift = shift % 32
        for i in 0 ..< width {
            if i - k - 1 >= 0 && shift != 0 {
                pn[i - k - 1] |= (a[i] << (32 - shift))
            }
            if i - k >= 0 {
                pn[i - k] |= (a[i] >> shift)
            }
        }
        return pn
    }

    static func multiply(_ a: [UInt32], _ b32: UInt32) -> [UInt32] {
        var pn = a
        var carry = UInt64(0)
        for i in 0 ..< width {
            let n = carry + UInt64(b32) * UInt64(pn[i])
            pn[i] = UInt32(n & 0xffffffff)
            carry = n >> 32
        }
        return pn
    }


    // Returns the position of the highest bit set plus one, or zero if the value is zero.
    static func getBits(_ pn: [UInt32]) -> UInt32 {
        for pos in (0 ..< width).reversed() {
            if pn[pos] != 0 {
                for nbits in (1 ... 31).reversed() {
                    if (pn[pos] & UInt32(1) << nbits) != 0 {
                        return UInt32(32 * pos + nbits + 1)
                    }
                }
                return UInt32(32 * pos + 1)
            }
        }
        return 0
    }

    static func getLow64(_ pn: [UInt32]) -> UInt64 {
        UInt64(pn[0]) | UInt64(pn[1]) << 32
    }

    /// This implementation directly uses shifts instead of going through an intermediate MPI representation.
    ///
    /// Also known as `SetCompact()`.
    ///
    static func makeCompact(compact: UInt32, negative: inout Bool, overflow: inout Bool) -> [UInt32] {
        var this = [UInt32](repeating: 0, count: width)
        let size = Int32(compact >> 24)
        var word: UInt32 = compact & 0x007fffff
        if (size <= 3) {
            word >>= 8 * (3 - size)
            assignTo(&this, UInt64(word))
        } else {
            assignTo(&this, UInt64(word))
            this = shiftLeft(this, shift: UInt32(8 * (size - 3)))
        }
        if negative {
            negative = word != 0 && (compact & 0x00800000) != 0
        }
        if overflow {
            overflow = word != 0 && ((size > 34) ||
                                     (word > 0xff && size > 33) ||
                                     (word > 0xffff && size > 32))
        }
        return this
    }

    static func getCompact(_ this: [UInt32], negative: Bool) -> UInt32 {
        var size = Int32((getBits(this) + 7) / 8)
        var compact = UInt32(0)
        if size <= 3 {
            compact = UInt32(getLow64(this) << 8 * (3 - UInt64(size)))
        } else {
            let bn: [UInt32] = multiply(shiftRight(this, shift: 8), UInt32(size - 3))
            compact = UInt32(getLow64(bn))
        }
        // The 0x00800000 bit denotes the sign.
        // Thus, if it is already set, divide the mantissa by 256 and increase the exponent.
        if (compact & 0x00800000) != 0 {
            compact >>= 8
            size += 1
        }
        assert((compact & ~UInt32(0x007fffff)) == 0)
        assert(size < 256)
        compact |= UInt32(size << 24)
        compact |= negative && (compact & 0x007fffff) != 0 ? 0x00800000 : 0
        return compact
    }

    static func arith256ToData(_ a: [UInt32]) -> Data {
        precondition(a.count == width)
        var ret = Data(count: bytes)
        var offset = ret.startIndex
        for i in 0 ..< width {
            offset = ret.addBytes(a[i], at: offset)
        }
        return ret
    }

    static func dataToArith256(_ data: Data) -> [UInt32] {
        precondition(data.count == bytes)
        var data = data
        var ret = [UInt32](repeating: 0, count: width)
        for i in 0 ..< width {
            ret[i] = data.withUnsafeBytes { $0.loadUnaligned(as: UInt32.self) }
            data = data.dropFirst(MemoryLayout<UInt32>.size)
        }
        return ret
    }
}
