#if !canImport(CryptoKit) // Targets non-Apple platforms using swift-crypto
import Crypto

@available(macOS 10.15, iOS 13, watchOS 6, tvOS 13, macCatalyst 13, visionOS 1.0, *)
extension HashFunction {
    /// Polyfill giving all HashFunctions the ability to accept a RawSpan on Linux.
    @inlinable
    public mutating func update(bytes: RawSpan) {
        bytes.withUnsafeBytes { bufferPointer in
            self.update(bufferPointer: bufferPointer)
        }
    }

    /// 2. Static polyfill for one-shot hashing
    @inlinable
    public static func hash(bytes: RawSpan) -> Self.Digest {
        var hasher = Self()
        hasher.update(bytes: bytes)
        return hasher.finalize()
    }
}
#endif
