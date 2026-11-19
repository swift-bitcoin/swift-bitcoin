package import protocol Crypto.HashFunction

/// Hashes first using ``SHA256`` and applies `SHA256` again on finalize.
package struct SHA256d: HashFunction {
    package typealias Digest = SHA256.Digest
    package static let blockByteCount = SHA256.blockByteCount

    private var sha256 = SHA256()

    package init() {}

    package mutating func update(bufferPointer: UnsafeRawBufferPointer) {
        sha256.update(bufferPointer: bufferPointer)
    }

    package func finalize() -> Digest {
        var hash256 = SHA256()
        sha256.finalize().withUnsafeBytes {
            hash256.update(bufferPointer: $0)
        }
        return hash256.finalize()
    }
}
