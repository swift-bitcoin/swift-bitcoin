package import protocol Crypto.HashFunction

/// Hashes first using ``SHA256`` and applies ``RIPEMD160`` on finalize.
package struct Hash160: HashFunction {
    package typealias Digest = RIPEMD160.Digest
    package static let blockByteCount = SHA256.blockByteCount

    private var sha256 = SHA256()

    package init() {}

    package mutating func update(bufferPointer: UnsafeRawBufferPointer) {
        sha256.update(bufferPointer: bufferPointer)
    }

    package func finalize() -> Digest {
        var hash160 = RIPEMD160()
        sha256.finalize().withUnsafeBytes {
            hash160.update(bufferPointer: $0)
        }
        return hash160.finalize()
    }
}
