import Foundation

/// An object that encodes values into a native binary format for external representation.
public struct BinaryEncoder {

    /// Initializes an encoder with the specified capacity.
    ///
    /// Use ``BinaryEncodingSizeCounter`` to pre-calculate the size.
    public init(size: Int) {
        data = .init(count: size)
    }

    /// Initializes an encoder from a binary encoding size counter.
    public init(_ counter: BinaryEncodingSizeCounter) {
        data = .init(count: counter.size)
    }

    /// The data which has been encoded so far.
    public private(set) var data: Data

    private var offset = 0

    public mutating func encode<D: DataProtocol & ContiguousBytes>(_ data: D, variable: Bool = false) {
        if variable {
            let varInt = VarInt(data.count)
            encode(varInt)
        }
        let nextOffset = offset + data.count
        self.data.withUnsafeMutableBytes { destination in
            data.withUnsafeBytes { source in
                destination[offset ..< nextOffset].copyBytes(from: source)
            }
        }
        offset = nextOffset
    }

    public mutating func encode<T: BinaryEncodable>(_ value: T) {
        value.encode(to: &self)
    }

    mutating func encode<T: BinaryEncodingPrimitive>(_ value: T) {
        let count = MemoryLayout.size(ofValue: value)
        let nextOffset = offset + count
        data.withUnsafeMutableBytes {
            $0.storeBytes(of: value, toByteOffset: offset, as: T.self)
        }
        offset = nextOffset
    }
}
