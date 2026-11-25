public import protocol Crypto.Digest

extension SipHash {

    /// A 64-bit (8-byte) SipHash digest.
    ///
    /// As a `Sequence` of `UInt8` it yields the eight bytes in little-endian order, the
    /// byte order used by the reference implementation's test vectors. `value` is the same
    /// number as an integer.
    public struct Digest: Crypto.Digest, Sendable {

        public static let byteCount = 8

        /// The digest as an integer (the little-endian interpretation of the eight digest bytes).
        public let value: UInt64

        /// Creates a digest from its integer value.
        public init(value: UInt64) {
            self.value = value
        }

        /// Creates a digest from exactly 8 little-endian bytes, or returns `nil` for any other length.
        public init?(bytes: Span<UInt8>) {
            guard bytes.count == Self.byteCount else { return nil }
            var value: UInt64 = 0
            for i in 0..<Self.byteCount { value |= UInt64(bytes[i]) &<< UInt64(i &* 8) }
            self.value = value
        }

        /// The digest as a lowercase hexadecimal string of its little-endian bytes (16 characters).
        public var hexString: String {
            let alphabet = Array("0123456789abcdef")
            var result = ""
            result.reserveCapacity(Self.byteCount * 2)
            for i in 0..<Self.byteCount {
                let byte = UInt8(truncatingIfNeeded: value &>> UInt64(i &* 8))
                result.append(alphabet[Int(byte &>> 4)])
                result.append(alphabet[Int(byte & 0x0f)])
            }
            return result
        }

        // MARK: Digest / ContiguousBytes

        /// The eight bytes are always presented little-endian, regardless of the platform.
        @unsafe
        public func withUnsafeBytes<R>(_ body: (UnsafeRawBufferPointer) throws -> R) rethrows -> R {
            try Swift.withUnsafeBytes(of: value.littleEndian, body)
        }

        // MARK: CustomStringConvertible

        public var description: String { "SipHash digest: \(hexString)" }
    }
}
