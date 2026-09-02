import Foundation

/// An object that encodes values into a native binary format for external representation.
public struct BinaryEncoder {

    /// Initializes an encoder with the specified capacity.
    ///
    /// Use ``BinarySizeCounter`` to pre-calculate the size.
    public init(size: Int) {
        data = .init(count: size)
    }

    /// Initializes an encoder from a binary binary size counter.
    public init(_ counter: BinarySizeCounter) {
        data = .init(count: counter.size)
    }

    /// The data which has been encoded so far.
    public private(set) var data: Data

    private var offset = 0

    public mutating func encode<D: DataProtocol & ContiguousBytes>(_ data: D, variable: Bool = false, byteSwapped: Bool = false) {
        let data = byteSwapped ? Data(data.reversed()) : Data(data)
        if variable {
            let varInt = VarInt(data.count)
            //encode(varInt)
            let varIntData = varInt.data
            self.data.replaceSubrange(offset ..< offset.advanced(by: varIntData.count), with: varIntData)
            offset += varIntData.count
        }
        let nextOffset = offset + data.count
        self.data.withUnsafeMutableBytes { destination in
            data.withUnsafeBytes { source in
                destination[offset ..< nextOffset].copyBytes(from: source)
            }
        }
        offset = nextOffset
    }

    public mutating func encodeArray<T: BinaryEncodingPrimitive>(_ array: [T]) {
        let nextOffset = offset + array.count * MemoryLayout<T>.size
        self.data.withUnsafeMutableBytes { destination in
            array.withUnsafeBytes { source in
                destination[offset ..< nextOffset].copyBytes(from: source)
            }
        }
        offset = nextOffset
    }

    public mutating func encode<T: BinaryEncodableLegacy>(_ value: T) {
        encode(value, format: nil)
    }

    public mutating func encode<T: BinaryEncodableLegacy>(_ value: T, format: T.BinaryFormat?) {
        value.encode(into: &self, format: format)
    }

    mutating func encode<T: BinaryEncodingPrimitive>(_ value: T) {
        let count = MemoryLayout.size(ofValue: value)
        let nextOffset = offset + count
        data.withUnsafeMutableBytes {
            $0.storeBytes(of: value, toByteOffset: offset, as: T.self)
        }
        offset = nextOffset
    }

    public static func encode<T: BinaryEncodingPrimitive>(_ value: T) -> Data {
        var counter = BinarySizeCounter()
        counter.count(value)
        var encoder = BinaryEncoder(counter)
        encoder.encode(value)
        return encoder.data
    }
}
