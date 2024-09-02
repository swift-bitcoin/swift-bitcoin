import Crypto

/// Implementation of the SipHash 2-4 hashing algorithm used by BIP152 short transaction identifiers.
///
/// More information on this [article](https://en.wikipedia.org/wiki/SipHash).
/// 
public struct SipHash: HashFunction {

    public struct Digest: Crypto.Digest {

        typealias Buffer = (UInt64, UInt64, UInt64, UInt64)

        init(_ v: Buffer) {
            value = v.0 ^ v.1 ^ v.2 ^ v.3
        }

        public let value: UInt64

        public func withUnsafeBytes<R>(_ body: (UnsafeRawBufferPointer) throws -> R) rethrows -> R {
            try Swift.withUnsafeBytes(of: value, body)
        }

        public static let byteCount = 8
    }

    public init() {
        self.init(k0: UInt64.random(in: 0 ... UInt64.max), k1: UInt64.random(in: 0 ... UInt64.max))
    }

    public init(k0: UInt64, k1: UInt64) {
        v.0 ^= k0
        v.1 ^= k1
        v.2 ^= k0
        v.3 ^= k1
    }

    /// Message digest buffer.
    /// Initialized with the bytes of  "somepseudorandomlygeneratedbytes".
    private var v = Digest.Buffer(0x736f6d6570736575, 0x646f72616e646f6d, 0x6c7967656e657261, 0x7465646279746573)

    private var pendingBytes = UInt64(0)
    private var pendingByteCount = 0
    private var byteCount = 0

    public mutating func update(bufferPointer buffer: UnsafeRawBufferPointer) {
        precondition(byteCount >= 0)

        // Use the first couple of bytes to complete the pending word.
        var i = 0
        if pendingByteCount > 0 {
            let readCount = min(buffer.count, 8 - pendingByteCount)
            var m: UInt64 = 0
            switch readCount {
            case 7:
                m |= UInt64(buffer[6]) << 48
                fallthrough
            case 6:
                m |= UInt64(buffer[5]) << 40
                fallthrough
            case 5:
                m |= UInt64(buffer[4]) << 32
                fallthrough
            case 4:
                m |= UInt64(buffer[3]) << 24
                fallthrough
            case 3:
                m |= UInt64(buffer[2]) << 16
                fallthrough
            case 2:
                m |= UInt64(buffer[1]) << 8
                fallthrough
            case 1:
                m |= UInt64(buffer[0])
            default:
                precondition(readCount == 0)
            }
            pendingBytes |= m << UInt64(pendingByteCount << 3)
            pendingByteCount += readCount
            i += readCount

            if pendingByteCount == 8 {
                v = compressWord(pendingBytes, v)
                pendingBytes = 0
                pendingByteCount = 0
            }
        }

        let left = (buffer.count - i) & 7
        let end = (buffer.count - i) - left
        while i < end {
            var m: UInt64 = 0
            withUnsafeMutableBytes(of: &m) { p in
                p.copyMemory(from: .init(rebasing: buffer[i ..< i + 8]))
            }
            v = compressWord(UInt64(littleEndian: m), v)
            i += 8
        }

        switch left {
        case 7:
            pendingBytes |= UInt64(buffer[i + 6]) << 48
            fallthrough
        case 6:
            pendingBytes |= UInt64(buffer[i + 5]) << 40
            fallthrough
        case 5:
            pendingBytes |= UInt64(buffer[i + 4]) << 32
            fallthrough
        case 4:
            pendingBytes |= UInt64(buffer[i + 3]) << 24
            fallthrough
        case 3:
            pendingBytes |= UInt64(buffer[i + 2]) << 16
            fallthrough
        case 2:
            pendingBytes |= UInt64(buffer[i + 1]) << 8
            fallthrough
        case 1:
            pendingBytes |= UInt64(buffer[i])
        default:
            precondition(left == 0)
        }
        pendingByteCount = left

        byteCount += buffer.count
    }

    public func finalize() -> Digest {
        precondition(byteCount >= 0)
        var pendingBytes = pendingBytes
        pendingBytes |= UInt64(byteCount) << 56
        // byteCount = -1

        var v = compressWord(pendingBytes, v)

        v.2 ^= 0xff
        for _ in 0 ..< SipHash.d {
            v = sipRound(v)
        }

        return Digest(v)
    }

    public static let blockByteCount = 8 // 64 / 8

    /// SipHash 2-4 means c == 2 and d == 4.
    public static let c = 2

    /// SipHash 2-4 means c == 2 and d == 4.
    public static let d = 4

}

private func sipRound(_ v: SipHash.Digest.Buffer) -> SipHash.Digest.Buffer {
    var v = v
    v.0 = v.0 &+ v.1
    v.1 = rotateLeft(v.1, by: 13)
    v.1 ^= v.0
    v.0 = rotateLeft(v.0, by: 32)
    v.2 = v.2 &+ v.3
    v.3 = rotateLeft(v.3, by: 16)
    v.3 ^= v.2
    v.0 = v.0 &+ v.3
    v.3 = rotateLeft(v.3, by: 21)
    v.3 ^= v.0
    v.2 = v.2 &+ v.1
    v.1 = rotateLeft(v.1, by: 17)
    v.1 ^= v.2
    v.2 = rotateLeft(v.2, by: 32)
    return v
}

private func compressWord(_ m: UInt64, _ v: SipHash.Digest.Buffer) -> SipHash.Digest.Buffer {
    var v = v
    v.3 ^= m
    for _ in 0 ..< SipHash.c {
        v = sipRound(v)
    }
    v.0 ^= m
    return v
}

private func rotateLeft(_ value: UInt64, by amount: UInt64) -> UInt64 {
    (value << amount) | (value >> (64 - amount))
}
