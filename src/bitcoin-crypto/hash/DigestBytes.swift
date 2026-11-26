import struct Crypto.SHA256

extension SHA256.Digest {

    /// The 32 digest bytes, copied out through the digest's `Sequence` conformance.
    ///
    /// This is the one place where a digest is turned back into bytes. It is safe (no
    /// pointers), at the price of one temporary heap allocation inside swift-crypto's
    /// iterator. See the README for the measured cost.
    var copiedBytes: InlineArray<32, UInt8> {
        var result = InlineArray<32, UInt8>(repeating: 0)
        var index = 0
        for byte in self {
            result[index] = byte
            index &+= 1
        }
        return result
    }
}
