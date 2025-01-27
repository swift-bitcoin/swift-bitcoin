import Foundation

/// Pre-calculates a binary encoding size by accumulating the byte count of values.
public struct BinaryEncodingSizeCounter {

    /// Initializes a size counter at zero bytes.
    public init() { }

    /// The accumulated encoded data length, in bytes.
    public private(set) var size = 0

    /// Accumulates an explicit size in bytes.
    public mutating func countSize(_ size: Int) {
        self.size += size
    }

    /// Counts the memory footprint of the primitive type, in bytes.
    public mutating func count<T: BinaryEncodingPrimitive>(_ type: T.Type) {
        countSize(MemoryLayout<T>.size)
    }

    /// Counts the variable length of the data assuming it will be encoded with a variable integer as the element count prefix.
    public mutating func count(_ data: Data, variable: Bool = false) {
        if variable {
            count(VarInt(data.count))
        }
        countSize(data.count)
    }

    /// Counts the memory footprint of the primitive element type times the length of the array plus the variable integer prefix of the element count.
    public mutating func count<E>(_ array: Array<E>) where E: BinaryEncodingPrimitive {
        count(VarInt(array.count))
        countSize(MemoryLayout<E>.size * array.count)
    }

    /// Counts the size of an encodable value.
    public mutating func count<T: BinaryEncodable>(_ value: T) {
        value.encodingSize(&self)
    }

    /// Counts the size of a primitive type value.
    mutating func countPrimitive<T: BinaryEncodingPrimitive>(_ value: T) {
        countSize(MemoryLayout.size(ofValue: value))
    }
}
