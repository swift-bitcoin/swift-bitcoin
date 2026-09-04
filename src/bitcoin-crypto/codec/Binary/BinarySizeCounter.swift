import Foundation

/// Pre-calculates a binary size by accumulating the byte count of values.
public struct BinarySizeCounter {

    /// Initializes a size counter at zero bytes.
    public init() { }

    /// The accumulated encoded data length, in bytes.
    public private(set) var size = 0

    /// Accumulates an explicit size in bytes.
    public mutating func countSize(_ size: Int) {
        self.size += size
    }

    /// Counts the memory footprint of the primitive type, in bytes.
    public mutating func count<T: FixedWidthInteger>(_ type: T.Type) {
        countSize(MemoryLayout<T>.size)
    }

    /// Counts the variable length of the data assuming it will be encoded with a variable integer as the element count prefix.
    public mutating func count(_ data: Data, variable: Bool = false) {
        if variable {
            count(VarInt(data.count))
        }
        countSize(data.count)
    }

    public mutating func count<T: BinaryEncodable>(_ value: T) {
        count(value, format: nil)
    }

    public mutating func count<T: BinaryEncodable>(_ value: T, format: T.BinaryFormat?) {
        value.countBytes(into: &self, format: format)
    }
}
