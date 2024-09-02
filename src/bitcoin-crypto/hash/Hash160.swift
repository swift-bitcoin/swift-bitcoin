import Foundation
import Crypto

/// Hashes first using ``SHA256`` and applies ``RIPEMD160`` on finalize.
public struct Hash160: HashFunction {

    public typealias Digest = RIPEMD160.Digest
    public static let blockByteCount = SHA256.blockByteCount

    private var sha256 = SHA256()

    public init() { }

    public mutating func update(bufferPointer: UnsafeRawBufferPointer) {
        sha256.update(bufferPointer: bufferPointer)
    }

    public func finalize() -> Digest {
        var hash160 = RIPEMD160()
        sha256.finalize().withUnsafeBytes {
            hash160.update(bufferPointer: $0)
        }
        return hash160.finalize()
    }
}
