import Foundation
import BitcoinCrypto

// MARK: - Serialization helper functions

/// Helper functions for serialization.
extension Data {

    init<T>(value: T) {
        self.init(count: MemoryLayout.size(ofValue: value))
        addBytes(value)
    }

    /// Appends the value's binary contents.
    /// - Parameter value: The value whose bytes will be copied.
    mutating func appendBytes<T>(_ value: T) {
        Swift.withUnsafeBytes(of: value) {
            append(contentsOf: $0)
        }
    }

    /// Replaces bytes at `offset` with the binary contents of `value`.
    /// - Parameters:
    ///   - value: The source value whose bytes will be copied.
    ///   - offset: The destination position at which the source bytes will be copied.
    /// - Returns: An discardable offset right after the copied bytes to use when calling this method repeteadly.
    @discardableResult
    mutating func addBytes<T>(_ value: T, at offset: Self.Index? = nil) -> Self.Index {
        let offset = offset ?? startIndex
        let count = MemoryLayout.size(ofValue: value)
        precondition(self[offset...].count >= count)
        Swift.withUnsafePointer(to: value) { replaceSubrange(offset ..< offset.advanced(by: count), with: $0, count: count) }
        return offset.advanced(by: count)
    }

    @discardableResult
    mutating func addData<T: DataProtocol>(_ value: T, at offset: Self.Index? = nil) -> Self.Index {
        let offset = offset ?? startIndex
        let count = value.count
        precondition(self[offset...].count >= count)
        replaceSubrange(offset ..< offset.advanced(by: count), with: value)
        return offset.advanced(by: count)
    }
}

// MARK: - Variable Integer (Compact Integer)

// TODO: - Remove extension in favor of direct VarInt BinaryCodable usage, check that Int is OK for all message values
extension Data {

    /// Converts a 64-bit integer into its compact integer representation – i.e. variable length data.
    init(varInt value: UInt64) {
        self = VarInt(rawValue: value).data
    }

    /// Parses bytes interpreted as variable length – i.e. compact integer – data into a 64-bit integer.
    var varInt: UInt64? {
        try? VarInt(self).rawValue
    }
}

// TODO: - Remove extension in favor of direct VarInt BinaryCodable usage, check that Int is OK for all message values
extension UInt64 {

    var varIntSize: Int {
        VarInt(rawValue: self).binarySize
    }
}
