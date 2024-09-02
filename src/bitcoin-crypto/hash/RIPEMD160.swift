import Foundation
import Crypto

/// RACE Integrity Primitives Evaluation (RIPE) 160-bit Message Digest (MD) implementation.
///
/// More information on this [article](https://en.wikipedia.org/wiki/RIPEMD).
/// 
public struct RIPEMD160: HashFunction {

    public struct Digest: Crypto.Digest {

        typealias Buffer = (UInt32, UInt32, UInt32, UInt32, UInt32)

        init(_ digestBuffer: Buffer) {
            let result = [digestBuffer.0, digestBuffer.1, digestBuffer.2, digestBuffer.3, digestBuffer.4]
            data = result.withUnsafeBytes { Data($0) }
        }

        let data: Data

        public func withUnsafeBytes<R>(_ body: (UnsafeRawBufferPointer) throws -> R) rethrows -> R {
            try data.withUnsafeBytes(body)
        }

        public static let byteCount = 20
    }

    public init() { }

    /// Message digest buffer.
    private var digestBuffer = Digest.Buffer(0x67452301, 0xefcdab89, 0x98badcfe, 0x10325476, 0xc3d2e1f0)

    /// Remaining data buffer.
    private var buffer = [UInt8]()

    /// Total amount of bytes processed.
    private var count = Int64(0)

    public mutating func update(bufferPointer: UnsafeRawBufferPointer) {
        var bigX = [UInt32](repeating: 0, count: 16)
        var pos = bufferPointer.startIndex
        var length = bufferPointer.count

        // Process remaining bytes from last call:
        if buffer.count > 0 && buffer.count + length >= 64 {
            let amount = 64 - buffer.count
            buffer.append(contentsOf: bufferPointer[..<pos.advanced(by: amount)])
            bigX.withUnsafeMutableBytes {
                _ = buffer.copyBytes(to: $0)
            }
            digestBuffer = compress(bigX, digestBuffer: digestBuffer)
            pos += amount
            length -= amount
        }

        // Process 64 byte chunks:
        while length >= 64 {
            bigX.withUnsafeMutableBytes {
                _ = bufferPointer[pos ..< (pos + 64)].copyBytes(to: $0)
            }
            digestBuffer = compress(bigX, digestBuffer: digestBuffer)
            pos += 64
            length -= 64
        }

        // Save remaining unprocessed bytes:
        buffer = .init(bufferPointer[pos...])
        count += Int64(bufferPointer.count)
    }

    public func finalize() -> Digest {
        var bigX = [UInt32](repeating: 0, count: 16)
        /* append the bit m_n == 1 */
        var buffer = self.buffer
        var digestBuffer = digestBuffer // This function cannot be mutating
        buffer.append(0x80)
        bigX.withUnsafeMutableBytes {
            _ = buffer.copyBytes(to: $0)
        }

        if (count & 63) > 55 {
            /* length goes to next block */
            digestBuffer = compress(bigX, digestBuffer: digestBuffer)
            bigX = [UInt32](repeating: 0, count: 16)
        }

        /* append length in bits */
        let lswlen = UInt32(truncatingIfNeeded: count)
        let mswlen = UInt32(UInt64(count) >> 32)
        bigX[14] = lswlen << 3
        bigX[15] = (lswlen >> 29) | (mswlen << 3)
        digestBuffer = compress(bigX, digestBuffer: digestBuffer)
        buffer = .init()
        return Digest(digestBuffer)
    }

    public static let blockByteCount = 8
}

/// Helper functions (originally macros in rmd160.h)
/// - Parameter bigX: `UnsafePointer<UInt32>`
private func compress(_ bigX: UnsafePointer<UInt32>, digestBuffer: RIPEMD160.Digest.Buffer) -> RIPEMD160.Digest.Buffer {

    /** ROL(x, n) cyclically rotates x over n bits to the left */
    /** x must be of an unsigned 32 bits type and 0 <= n < 32. */
    func ROL(_ x: UInt32, _ n: UInt32) -> UInt32 {
        (x << n) | ( x >> (32 - n))
    }

    /* the five basic functions F(), G() and H() */
    func F(_ x: UInt32, _ y: UInt32, _ z: UInt32) -> UInt32 {
        x ^ y ^ z
    }

    func G(_ x: UInt32, _ y: UInt32, _ z: UInt32) -> UInt32 {
        (x & y) | (~x & z)
    }

    func H(_ x: UInt32, _ y: UInt32, _ z: UInt32) -> UInt32 {
        (x | ~y) ^ z
    }

    func I(_ x: UInt32, _ y: UInt32, _ z: UInt32) -> UInt32 {
        (x & z) | (y & ~z)
    }

    func J(_ x: UInt32, _ y: UInt32, _ z: UInt32) -> UInt32 {
        x ^ (y | ~z)
    }

    /* the ten basic operations FF() through III() */
    func FF(_ a: inout UInt32, _ b: UInt32, _ c: inout UInt32, _ d: UInt32, _ e: UInt32, _ x: UInt32, _ s: UInt32) {
        a = a &+ F(b, c, d) &+ x
        a = ROL(a, s) &+ e
        c = ROL(c, 10)
    }

    func GG(_ a: inout UInt32, _ b: UInt32, _ c: inout UInt32, _ d: UInt32, _ e: UInt32, _ x: UInt32, _ s: UInt32) {
        a = a &+ G(b, c, d) &+ x &+ 0x5a827999
        a = ROL(a, s) &+ e
        c = ROL(c, 10)
    }

    func HH(_ a: inout UInt32, _ b: UInt32, _ c: inout UInt32, _ d: UInt32, _ e: UInt32, _ x: UInt32, _ s: UInt32) {
        a = a &+ H(b, c, d) &+ x &+ 0x6ed9eba1
        a = ROL(a, s) &+ e
        c = ROL(c, 10)
    }

    func II(_ a: inout UInt32, _ b: UInt32, _ c: inout UInt32, _ d: UInt32, _ e: UInt32, _ x: UInt32, _ s: UInt32) {
        a = a &+ I(b, c, d) &+ x &+ 0x8f1bbcdc
        a = ROL(a, s) &+ e
        c = ROL(c, 10)
    }

    func JJ(_ a: inout UInt32, _ b: UInt32, _ c: inout UInt32, _ d: UInt32, _ e: UInt32, _ x: UInt32, _ s: UInt32) {
        a = a &+ J(b, c, d) &+ x &+ 0xa953fd4e
        a = ROL(a, s) &+ e
        c = ROL(c, 10)
    }

    func FFF(_ a: inout UInt32, _ b: UInt32, _ c: inout UInt32, _ d: UInt32, _ e: UInt32, _ x: UInt32, _ s: UInt32) {
        a = a &+ F(b, c, d) &+ x
        a = ROL(a, s) &+ e
        c = ROL(c, 10)
    }

    func GGG(_ a: inout UInt32, _ b: UInt32, _ c: inout UInt32, _ d: UInt32, _ e: UInt32, _ x: UInt32, _ s: UInt32) {
        a = a &+ G(b, c, d) &+ x &+ 0x7a6d76e9
        a = ROL(a, s) &+ e
        c = ROL(c, 10)
    }

    func HHH(_ a: inout UInt32, _ b: UInt32, _ c: inout UInt32, _ d: UInt32, _ e: UInt32, _ x: UInt32, _ s: UInt32) {
        a = a &+ H(b, c, d) &+ x &+ 0x6d703ef3
        a = ROL(a, s) &+ e
        c = ROL(c, 10)
    }

    func III(_ a: inout UInt32, _ b: UInt32, _ c: inout UInt32, _ d: UInt32, _ e: UInt32, _ x: UInt32, _ s: UInt32) {
        a = a &+ I(b, c, d) &+ x &+ 0x5c4dd124
        a = ROL(a, s) &+ e
        c = ROL(c, 10)
    }

    func JJJ(_ a: inout UInt32, _ b: UInt32, _ c: inout UInt32, _ d: UInt32, _ e: UInt32, _ x: UInt32, _ s: UInt32) {
        a = a &+ J(b, c, d) &+ x &+ 0x50a28be6
        a = ROL(a, s) &+ e
        c = ROL(c, 10)
    }

    /* The hashing function starts here */
    var (aa, bb, cc, dd, ee) = digestBuffer
    var (aaa, bbb, ccc, ddd, eee) = digestBuffer

    /* Round 1 */
    FF(&aa, bb, &cc, dd, ee, bigX[ 0], 11)
    FF(&ee, aa, &bb, cc, dd, bigX[ 1], 14)
    FF(&dd, ee, &aa, bb, cc, bigX[ 2], 15)
    FF(&cc, dd, &ee, aa, bb, bigX[ 3], 12)
    FF(&bb, cc, &dd, ee, aa, bigX[ 4],  5)
    FF(&aa, bb, &cc, dd, ee, bigX[ 5],  8)
    FF(&ee, aa, &bb, cc, dd, bigX[ 6],  7)
    FF(&dd, ee, &aa, bb, cc, bigX[ 7],  9)
    FF(&cc, dd, &ee, aa, bb, bigX[ 8], 11)
    FF(&bb, cc, &dd, ee, aa, bigX[ 9], 13)
    FF(&aa, bb, &cc, dd, ee, bigX[10], 14)
    FF(&ee, aa, &bb, cc, dd, bigX[11], 15)
    FF(&dd, ee, &aa, bb, cc, bigX[12],  6)
    FF(&cc, dd, &ee, aa, bb, bigX[13],  7)
    FF(&bb, cc, &dd, ee, aa, bigX[14],  9)
    FF(&aa, bb, &cc, dd, ee, bigX[15],  8)

    /* Round 2 */
    GG(&ee, aa, &bb, cc, dd, bigX[ 7],  7)
    GG(&dd, ee, &aa, bb, cc, bigX[ 4],  6)
    GG(&cc, dd, &ee, aa, bb, bigX[13],  8)
    GG(&bb, cc, &dd, ee, aa, bigX[ 1], 13)
    GG(&aa, bb, &cc, dd, ee, bigX[10], 11)
    GG(&ee, aa, &bb, cc, dd, bigX[ 6],  9)
    GG(&dd, ee, &aa, bb, cc, bigX[15],  7)
    GG(&cc, dd, &ee, aa, bb, bigX[ 3], 15)
    GG(&bb, cc, &dd, ee, aa, bigX[12],  7)
    GG(&aa, bb, &cc, dd, ee, bigX[ 0], 12)
    GG(&ee, aa, &bb, cc, dd, bigX[ 9], 15)
    GG(&dd, ee, &aa, bb, cc, bigX[ 5],  9)
    GG(&cc, dd, &ee, aa, bb, bigX[ 2], 11)
    GG(&bb, cc, &dd, ee, aa, bigX[14],  7)
    GG(&aa, bb, &cc, dd, ee, bigX[11], 13)
    GG(&ee, aa, &bb, cc, dd, bigX[ 8], 12)

    /* Round 3 */
    HH(&dd, ee, &aa, bb, cc, bigX[ 3], 11)
    HH(&cc, dd, &ee, aa, bb, bigX[10], 13)
    HH(&bb, cc, &dd, ee, aa, bigX[14],  6)
    HH(&aa, bb, &cc, dd, ee, bigX[ 4],  7)
    HH(&ee, aa, &bb, cc, dd, bigX[ 9], 14)
    HH(&dd, ee, &aa, bb, cc, bigX[15],  9)
    HH(&cc, dd, &ee, aa, bb, bigX[ 8], 13)
    HH(&bb, cc, &dd, ee, aa, bigX[ 1], 15)
    HH(&aa, bb, &cc, dd, ee, bigX[ 2], 14)
    HH(&ee, aa, &bb, cc, dd, bigX[ 7],  8)
    HH(&dd, ee, &aa, bb, cc, bigX[ 0], 13)
    HH(&cc, dd, &ee, aa, bb, bigX[ 6],  6)
    HH(&bb, cc, &dd, ee, aa, bigX[13],  5)
    HH(&aa, bb, &cc, dd, ee, bigX[11], 12)
    HH(&ee, aa, &bb, cc, dd, bigX[ 5],  7)
    HH(&dd, ee, &aa, bb, cc, bigX[12],  5)

    /* Round 4 */
    II(&cc, dd, &ee, aa, bb, bigX[ 1], 11)
    II(&bb, cc, &dd, ee, aa, bigX[ 9], 12)
    II(&aa, bb, &cc, dd, ee, bigX[11], 14)
    II(&ee, aa, &bb, cc, dd, bigX[10], 15)
    II(&dd, ee, &aa, bb, cc, bigX[ 0], 14)
    II(&cc, dd, &ee, aa, bb, bigX[ 8], 15)
    II(&bb, cc, &dd, ee, aa, bigX[12],  9)
    II(&aa, bb, &cc, dd, ee, bigX[ 4],  8)
    II(&ee, aa, &bb, cc, dd, bigX[13],  9)
    II(&dd, ee, &aa, bb, cc, bigX[ 3], 14)
    II(&cc, dd, &ee, aa, bb, bigX[ 7],  5)
    II(&bb, cc, &dd, ee, aa, bigX[15],  6)
    II(&aa, bb, &cc, dd, ee, bigX[14],  8)
    II(&ee, aa, &bb, cc, dd, bigX[ 5],  6)
    II(&dd, ee, &aa, bb, cc, bigX[ 6],  5)
    II(&cc, dd, &ee, aa, bb, bigX[ 2], 12)

    /* Round 5 */
    JJ(&bb, cc, &dd, ee, aa, bigX[ 4],  9)
    JJ(&aa, bb, &cc, dd, ee, bigX[ 0], 15)
    JJ(&ee, aa, &bb, cc, dd, bigX[ 5],  5)
    JJ(&dd, ee, &aa, bb, cc, bigX[ 9], 11)
    JJ(&cc, dd, &ee, aa, bb, bigX[ 7],  6)
    JJ(&bb, cc, &dd, ee, aa, bigX[12],  8)
    JJ(&aa, bb, &cc, dd, ee, bigX[ 2], 13)
    JJ(&ee, aa, &bb, cc, dd, bigX[10], 12)
    JJ(&dd, ee, &aa, bb, cc, bigX[14],  5)
    JJ(&cc, dd, &ee, aa, bb, bigX[ 1], 12)
    JJ(&bb, cc, &dd, ee, aa, bigX[ 3], 13)
    JJ(&aa, bb, &cc, dd, ee, bigX[ 8], 14)
    JJ(&ee, aa, &bb, cc, dd, bigX[11], 11)
    JJ(&dd, ee, &aa, bb, cc, bigX[ 6],  8)
    JJ(&cc, dd, &ee, aa, bb, bigX[15],  5)
    JJ(&bb, cc, &dd, ee, aa, bigX[13],  6)

    /* Parallel round 1 */
    JJJ(&aaa, bbb, &ccc, ddd, eee, bigX[ 5],  8)
    JJJ(&eee, aaa, &bbb, ccc, ddd, bigX[14],  9)
    JJJ(&ddd, eee, &aaa, bbb, ccc, bigX[ 7],  9)
    JJJ(&ccc, ddd, &eee, aaa, bbb, bigX[ 0], 11)
    JJJ(&bbb, ccc, &ddd, eee, aaa, bigX[ 9], 13)
    JJJ(&aaa, bbb, &ccc, ddd, eee, bigX[ 2], 15)
    JJJ(&eee, aaa, &bbb, ccc, ddd, bigX[11], 15)
    JJJ(&ddd, eee, &aaa, bbb, ccc, bigX[ 4],  5)
    JJJ(&ccc, ddd, &eee, aaa, bbb, bigX[13],  7)
    JJJ(&bbb, ccc, &ddd, eee, aaa, bigX[ 6],  7)
    JJJ(&aaa, bbb, &ccc, ddd, eee, bigX[15],  8)
    JJJ(&eee, aaa, &bbb, ccc, ddd, bigX[ 8], 11)
    JJJ(&ddd, eee, &aaa, bbb, ccc, bigX[ 1], 14)
    JJJ(&ccc, ddd, &eee, aaa, bbb, bigX[10], 14)
    JJJ(&bbb, ccc, &ddd, eee, aaa, bigX[ 3], 12)
    JJJ(&aaa, bbb, &ccc, ddd, eee, bigX[12],  6)

    /* Parallel round 2 */
    III(&eee, aaa, &bbb, ccc, ddd, bigX[ 6],  9)
    III(&ddd, eee, &aaa, bbb, ccc, bigX[11], 13)
    III(&ccc, ddd, &eee, aaa, bbb, bigX[ 3], 15)
    III(&bbb, ccc, &ddd, eee, aaa, bigX[ 7],  7)
    III(&aaa, bbb, &ccc, ddd, eee, bigX[ 0], 12)
    III(&eee, aaa, &bbb, ccc, ddd, bigX[13],  8)
    III(&ddd, eee, &aaa, bbb, ccc, bigX[ 5],  9)
    III(&ccc, ddd, &eee, aaa, bbb, bigX[10], 11)
    III(&bbb, ccc, &ddd, eee, aaa, bigX[14],  7)
    III(&aaa, bbb, &ccc, ddd, eee, bigX[15],  7)
    III(&eee, aaa, &bbb, ccc, ddd, bigX[ 8], 12)
    III(&ddd, eee, &aaa, bbb, ccc, bigX[12],  7)
    III(&ccc, ddd, &eee, aaa, bbb, bigX[ 4],  6)
    III(&bbb, ccc, &ddd, eee, aaa, bigX[ 9], 15)
    III(&aaa, bbb, &ccc, ddd, eee, bigX[ 1], 13)
    III(&eee, aaa, &bbb, ccc, ddd, bigX[ 2], 11)

    /* Parallel round 3 */
    HHH(&ddd, eee, &aaa, bbb, ccc, bigX[15],  9)
    HHH(&ccc, ddd, &eee, aaa, bbb, bigX[ 5],  7)
    HHH(&bbb, ccc, &ddd, eee, aaa, bigX[ 1], 15)
    HHH(&aaa, bbb, &ccc, ddd, eee, bigX[ 3], 11)
    HHH(&eee, aaa, &bbb, ccc, ddd, bigX[ 7],  8)
    HHH(&ddd, eee, &aaa, bbb, ccc, bigX[14],  6)
    HHH(&ccc, ddd, &eee, aaa, bbb, bigX[ 6],  6)
    HHH(&bbb, ccc, &ddd, eee, aaa, bigX[ 9], 14)
    HHH(&aaa, bbb, &ccc, ddd, eee, bigX[11], 12)
    HHH(&eee, aaa, &bbb, ccc, ddd, bigX[ 8], 13)
    HHH(&ddd, eee, &aaa, bbb, ccc, bigX[12],  5)
    HHH(&ccc, ddd, &eee, aaa, bbb, bigX[ 2], 14)
    HHH(&bbb, ccc, &ddd, eee, aaa, bigX[10], 13)
    HHH(&aaa, bbb, &ccc, ddd, eee, bigX[ 0], 13)
    HHH(&eee, aaa, &bbb, ccc, ddd, bigX[ 4],  7)
    HHH(&ddd, eee, &aaa, bbb, ccc, bigX[13],  5)

    /* Parallel round 4 */
    GGG(&ccc, ddd, &eee, aaa, bbb, bigX[ 8], 15)
    GGG(&bbb, ccc, &ddd, eee, aaa, bigX[ 6],  5)
    GGG(&aaa, bbb, &ccc, ddd, eee, bigX[ 4],  8)
    GGG(&eee, aaa, &bbb, ccc, ddd, bigX[ 1], 11)
    GGG(&ddd, eee, &aaa, bbb, ccc, bigX[ 3], 14)
    GGG(&ccc, ddd, &eee, aaa, bbb, bigX[11], 14)
    GGG(&bbb, ccc, &ddd, eee, aaa, bigX[15],  6)
    GGG(&aaa, bbb, &ccc, ddd, eee, bigX[ 0], 14)
    GGG(&eee, aaa, &bbb, ccc, ddd, bigX[ 5],  6)
    GGG(&ddd, eee, &aaa, bbb, ccc, bigX[12],  9)
    GGG(&ccc, ddd, &eee, aaa, bbb, bigX[ 2], 12)
    GGG(&bbb, ccc, &ddd, eee, aaa, bigX[13],  9)
    GGG(&aaa, bbb, &ccc, ddd, eee, bigX[ 9], 12)
    GGG(&eee, aaa, &bbb, ccc, ddd, bigX[ 7],  5)
    GGG(&ddd, eee, &aaa, bbb, ccc, bigX[10], 15)
    GGG(&ccc, ddd, &eee, aaa, bbb, bigX[14],  8)

    /* Parallel round 5 */
    FFF(&bbb, ccc, &ddd, eee, aaa, bigX[12] ,  8)
    FFF(&aaa, bbb, &ccc, ddd, eee, bigX[15] ,  5)
    FFF(&eee, aaa, &bbb, ccc, ddd, bigX[10] , 12)
    FFF(&ddd, eee, &aaa, bbb, ccc, bigX[ 4] ,  9)
    FFF(&ccc, ddd, &eee, aaa, bbb, bigX[ 1] , 12)
    FFF(&bbb, ccc, &ddd, eee, aaa, bigX[ 5] ,  5)
    FFF(&aaa, bbb, &ccc, ddd, eee, bigX[ 8] , 14)
    FFF(&eee, aaa, &bbb, ccc, ddd, bigX[ 7] ,  6)
    FFF(&ddd, eee, &aaa, bbb, ccc, bigX[ 6] ,  8)
    FFF(&ccc, ddd, &eee, aaa, bbb, bigX[ 2] , 13)
    FFF(&bbb, ccc, &ddd, eee, aaa, bigX[13] ,  6)
    FFF(&aaa, bbb, &ccc, ddd, eee, bigX[14] ,  5)
    FFF(&eee, aaa, &bbb, ccc, ddd, bigX[ 0] , 15)
    FFF(&ddd, eee, &aaa, bbb, ccc, bigX[ 3] , 13)
    FFF(&ccc, ddd, &eee, aaa, bbb, bigX[ 9] , 11)
    FFF(&bbb, ccc, &ddd, eee, aaa, bigX[11] , 11)

    /* Combine results */
    return (digestBuffer.1 &+ cc &+ ddd,
                digestBuffer.2 &+ dd &+ eee,
                digestBuffer.3 &+ ee &+ aaa,
                digestBuffer.4 &+ aa &+ bbb,
                digestBuffer.0 &+ bb &+ ccc)
}
