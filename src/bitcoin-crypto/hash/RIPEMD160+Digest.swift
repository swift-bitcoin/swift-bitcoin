public import protocol Crypto.Digest

extension RIPEMD160 {

    /// A 160-bit (20-byte) RIPEMD-160 digest.
    ///
    /// Equality is evaluated in constant time. As a `Sequence` of `UInt8`,
    /// `Array(digest)` yields the 20 digest bytes.
    public struct Digest: Crypto.Digest, Sendable {

        public static let byteCount = 20

        private var storage: InlineArray<20, UInt8>

        /// Builds a digest from the five little-endian state words.
        init(words: InlineArray<5, UInt32>) {
            storage = .init(repeating: 0)
            for w in 0..<5 {
                for b in 0..<4 {
                    storage[w &* 4 &+ b] = UInt8(truncatingIfNeeded: words[w] &>> UInt32(b &* 8))
                }
            }
        }

        /// Creates a digest from exactly 20 bytes, or returns `nil` for any other length.
        public init?(bytes: Span<UInt8>) {
            guard bytes.count == Self.byteCount else { return nil }
            storage = .init(repeating: 0)
            for i in 0..<Self.byteCount { storage[i] = bytes[i] }
        }

        /// Calls `body` with a view of the 20 digest bytes.
        public func withBytes<R, E: Error>(_ body: (Span<UInt8>) throws(E) -> R) throws(E) -> R {
            try body(storage.span)
        }

        /// The digest as a lowercase hexadecimal string (40 characters).
        public var hexString: String {
            let alphabet = Array("0123456789abcdef")
            var result = ""
            result.reserveCapacity(Self.byteCount * 2)
            for i in 0..<Self.byteCount {
                result.append(alphabet[Int(storage[i] &>> 4)])
                result.append(alphabet[Int(storage[i] & 0x0f)])
            }
            return result
        }

        // MARK: Digest / ContiguousBytes

        @unsafe
        public func withUnsafeBytes<R>(_ body: (UnsafeRawBufferPointer) throws -> R) rethrows -> R {
            try storage.span.withUnsafeBytes(body)
        }

        // MARK: Equatable / Hashable / CustomStringConvertible

        public static func == (lhs: Digest, rhs: Digest) -> Bool {
            var difference: UInt8 = 0
            for i in 0..<byteCount { difference |= lhs.storage[i] ^ rhs.storage[i] }
            return difference == 0
        }

        public func hash(into hasher: inout Hasher) {
            for i in 0..<Self.byteCount { hasher.combine(storage[i]) }
        }

        public var description: String { "RIPEMD160 digest: \(hexString)" }
    }
}
