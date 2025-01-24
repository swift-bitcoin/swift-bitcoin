import Foundation

public struct BinarySizeVisitor {

    public init() { }

    public private(set) var size = 0

    public mutating func countSize(_ size: Int) {
        self.size += size
    }

    public mutating func count<T: BinaryEncodingPrimitive>(_ type: T.Type) {
        countSize(MemoryLayout<T>.size)
    }

    public mutating func count<E>(_ array: Array<E>) where E: BinaryEncodingPrimitive {
        count(VarInt(array.count))
        countSize(MemoryLayout<E>.size * array.count)
    }

    public mutating func count<T: BinaryEncodable>(_ value: T) {
        value.reportSize(to: &self)
    }

    mutating func countPrimitive<T: BinaryEncodingPrimitive>(_ value: T) {
        countSize(MemoryLayout.size(ofValue: value))
    }
}
