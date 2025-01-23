import Foundation

public struct BinaryEncoder {

    public struct SizeVisitor {

        public init() { }

        public private(set) var size = 0

        public mutating func count<T: BinaryTrivial>(_ value: T) {
            size += MemoryLayout.size(ofValue: value)
        }

        public mutating func count<T: BinaryTrivial>(_ type: T.Type) {
            size += MemoryLayout<T>.size
        }

        public mutating func count<E>(_ array: Array<E>) where E: BinaryTrivial {
            count(VarInt(array.count))
            countSize(MemoryLayout<E>.size * array.count)
        }

        public mutating func count<C: Collection>(_ collection: C) {
            self.countSize(collection.count)
        }

        public mutating func count<T: BinaryEncodable>(_ value: T) {
            value.reportSize(to: &self)
        }

        public mutating func countSize(_ size: Int) {
            self.size += size
        }
    }

    public private(set) var data: Data
    private var offset = 0

    public init(count: Int) {
        data = .init(count: count)
    }

    public mutating func put<T: BinaryTrivial>(_ value: T) {
        let count = MemoryLayout.size(ofValue: value)
        let nextOffset = offset + count
        data.withUnsafeMutableBytes {
            $0.storeBytes(of: value, toByteOffset: offset, as: T.self)
        }
        offset = nextOffset
    }

    public mutating func put<E>(_ array: Array<E>) where E: BinaryTrivial {
        put(VarInt(array.count))
        for e in array {
            put(e)
        }
    }

    public mutating func put<D: DataProtocol & ContiguousBytes>(_ data: D) {
        let nextOffset = offset + data.count
        self.data.withUnsafeMutableBytes { destination in
            data.withUnsafeBytes { source in
                destination[offset ..< nextOffset].copyBytes(from: source)
            }
        }
        offset = nextOffset
    }

    public mutating func put<T: BinaryEncodable>(_ value: T) {
        value.encode(to: &self)
    }
}
