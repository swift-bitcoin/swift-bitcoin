import Foundation

struct DifficultyTarget: Comparable {

    init() {
        n = .init(repeating: 0, count: Self.width)
    }

    init(_ value: UInt64) {
        self.init()
        n[0] = UInt32(value)
        n[1] = UInt32(value >> 32)
    }

    init(_ data: Data) {
        precondition(data.count == Self.bytes)
        var data = data
        n = .init(repeating: 0, count: Self.width)
        for i in n.indices {
            n[i] = data.withUnsafeBytes { $0.loadUnaligned(as: UInt32.self) }
            data = data.dropFirst(MemoryLayout<UInt32>.size)
        }
    }

    init(compact: Int) {
        var discardNegative = false
        var discardOverflow = false
        self.init(compact: compact, negative: &discardNegative, overflow: &discardOverflow)
    }

    /// This implementation directly uses shifts instead of going through an intermediate MPI representation.
    ///
    /// Also known as `SetCompact()`.
    ///
    init(compact: Int, negative: inout Bool, overflow: inout Bool) {
        let compact = UInt32(compact)
        let size = Int(compact >> 24)
        var word: UInt32 = compact & 0x007fffff
        if (size <= 3) {
            word >>= 8 * (3 - size)
            self.init(UInt64(word))
        } else {
            self.init(UInt64(word))
            self <<= 8 * (size - 3)
        }
        negative = word != 0 && (compact & 0x00800000) != 0
        overflow = word != 0 && ((size > 34) ||
                                 (word > 0xff && size > 33) ||
                                 (word > 0xffff && size > 32))
    }

    private var n: [UInt32]

    var isZero: Bool {
        n.allSatisfy { $0 == 0 }
    }

    private var low64: UInt64 {
        UInt64(n[0]) | UInt64(n[1]) << 32
    }

    var data: Data {
        var data = Data(count: Self.bytes)
        var offset = data.startIndex
        for value in n {
            offset = data.addBytes(value, at: offset)
        }
        return data
    }

    // Returns the position of the highest bit set plus one, or zero if the value is zero.
    private var bits: Int {
        for i in n.indices.reversed() {
            if n[i] != 0 {
                for nBits in (1 ... 31).reversed() {
                    if (n[i] & UInt32(1) << nBits) != 0 {
                        return 32 * i + nBits + 1
                    }
                }
                return 32 * i + 1
            }
        }
        return 0
    }

    static func += (_ a: inout Self, _ value: UInt64) {
        a += Self(value)
    }

    static func += (_ a: inout Self, _ b: Self) {
        var carry = UInt64(0)
        for i in a.n.indices {
            let aux = carry + UInt64(a.n[i]) + UInt64(b.n[i])
            a.n[i] = UInt32(truncatingIfNeeded: aux & 0xffffffff)
            carry = aux >> 32
        }
    }

    static prefix func - (_ a: Self) -> Self {
        var a = a
        for i in a.n.indices {
            a.n[i] = ~a.n[i]
        }
        a += 1
        return a
    }

    static func -= (_ a: inout Self, _ b: Self) {
        a += -b
    }

    static func *= (_ a: inout Self, _ value: UInt32) {
        var carry = UInt64(0)
        for i in a.n.indices {
            let aux = carry + UInt64(value) * UInt64(a.n[i])
            a.n[i] = UInt32(aux & 0xffffffff)
            carry = aux >> 32
        }
    }

    static func /= (_ a: inout Self, _ b: Self) {
        var div = b // make a copy, so we can shift.
        var num = a // make a copy, so we can subtract.
        a = Self() // 0, the quotient.

        let numBits = num.bits
        let divBits = div.bits
        if divBits == 0 { fatalError() } // Division by zero
        if divBits > numBits { return } // the result is certainly 0.

        var shift = numBits - divBits
        div <<= shift // shift so that div and num align.
        while shift >= 0 {
            if num >= div {
                num -= div
                a.n[shift / 32] |= (UInt32(1) << (shift & 31)) // set a bit of the result.
            }
            div >>= 1 // shift back.
            shift -= 1
        }
        // num now contains the remainder of the division.
    }

    static func <<= (_ a: inout Self, _ shift: Int) {
        let aux = a
        for i in a.n.indices { a.n[i] = 0 }
        let k = shift / 32
        let shift = shift % 32
        for i in a.n.indices {
            if i + k + 1 < Self.width && shift != 0 {
                a.n[i + k + 1] |= (aux.n[i] >> (32 - shift))
            }
            if i + k < Self.width {
                a.n[i + k] |= (aux.n[i] << shift)
            }
        }
    }

    static func >>= (_ a: inout Self, _ shift: Int) {
        let aux = a
        for i in a.n.indices { a.n[i] = 0 }
        let k = shift / 32
        let shift = shift % 32
        for i in a.n.indices {
            if i - k - 1 >= 0 && shift != 0 {
                a.n[i - k - 1] |= (aux.n[i] << (32 - shift))
            }
            if i - k >= 0 {
                a.n[i - k] |= (aux.n[i] >> shift)
            }
        }
    }

    func toCompact(negative: Bool = false) -> Int {
        var size = (bits + 7) / 8
        var compact = UInt32(0)
        if size <= 3 {
            compact = UInt32(truncatingIfNeeded: low64 << (8 * (3 - size)))
        } else {
            var b = self
            b >>= 8 * (size - 3)
            compact = UInt32(truncatingIfNeeded: b.low64)
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

    private static let bytes = 256 / 8
    private static let width = 256 / 32

    /// Calculate the difficulty for a given block index.
    static func getDifficulty(_ compact: Int) -> Double {
        let compact = UInt32(compact)
        var shift = (compact >> 24) & 0xff
        var diff: Double = Double(0x0000ffff) / Double(compact & 0x00ffffff)

        while shift < 29 {
            diff *= 256.0
            shift += 1
        }

        while shift > 29 {
            diff /= 256.0
            shift -= 1
        }
        return diff
    }

    static func < (lhs: DifficultyTarget, rhs: DifficultyTarget) -> Bool {
        for i in (0 ..< width).reversed() {
            if lhs.n[i] < rhs.n[i] { return true }
            if lhs.n[i] > rhs.n[i] { return false }
        }
        return false
    }
}
