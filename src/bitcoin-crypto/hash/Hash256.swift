import Foundation
import Crypto

/// Hashes first using ``SHA256`` and applies `SHA256` again on finalize.
public struct Hash256: HashFunction {

    public typealias Digest = SHA256.Digest
    public static let blockByteCount = SHA256.blockByteCount

    private var sha256 = SHA256()

    public init() { }

    public mutating func update(bufferPointer: UnsafeRawBufferPointer) {
        sha256.update(bufferPointer: bufferPointer)
    }

    public func finalize() -> Digest {
        var hash256 = SHA256()
        sha256.finalize().withUnsafeBytes {
            hash256.update(bufferPointer: $0)
        }
        return hash256.finalize()
    }
}
