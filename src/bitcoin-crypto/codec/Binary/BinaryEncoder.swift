import Foundation

public struct BinaryEncoder {

    public init(count: Int) {
        data = .init(count: count)
    }

    public private(set) var data: Data
    private var offset = 0

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

    mutating func putPrimitive<T: BinaryEncodingPrimitive>(_ value: T) {
        let count = MemoryLayout.size(ofValue: value)
        let nextOffset = offset + count
        data.withUnsafeMutableBytes {
            $0.storeBytes(of: value, toByteOffset: offset, as: T.self)
        }
        offset = nextOffset
    }
}
