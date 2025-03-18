import Foundation

/// An object that decodes values from a native binary format into in-memory representations.
public struct BinaryDecoder {

    public init<D: DataProtocol>(_ data: D) {
        self.data = Data(data)
    }

    private var data: Data
    private var offset = 0
    private var limit = Int?.none
    private var checkpoint = Int?.none
    private var checkpointLimit = Int?.none

    /// Decodes data which may appear prefixed by its length as a variable integer.
    public mutating func decode(variable: Bool, byteSwapped: Bool = false) throws -> Data {
        if variable {
            let varInt: VarInt = try decode()
            return try decode(varInt.value, byteSwapped: byteSwapped)
        }
        return try decode(byteSwapped: byteSwapped)
    }

    /// Decodes data of the specified length or until there are no more bytes available.
    @discardableResult public mutating func decode(_ count: Int? = .none, byteSwapped: Bool = false) throws -> Data {
        let remaining = data.count - offset
        let count = if let count { count }
                    else if let limit { limit }
                    else { remaining }

        if let limit {
            if count <= limit { self.limit = limit - count }
            else { throw BinaryDecodingError.limitExceeded }
        }

        let nextOffset = offset + count
        guard nextOffset <= data.count else {
            throw BinaryDecodingError.outOfRange
        }

        var value = data[offset ..< nextOffset]
        if byteSwapped { value.reverse() }
        offset = nextOffset
        return Data(value)
    }

    /// Decodes a binary decodable object.
    public mutating func decode<T: BinaryDecodable>() throws -> T {
        try T(from: &self)
    }

    public mutating func decodeExplicit<T: BinaryDecodable>() throws -> T {
        try T(from: &self)
    }

    /// Decodes a custom binary decodable object.
    public mutating func decode<T: CustomBinaryDecodable>(encoding: T.Encoding?) throws -> T {
        try T(from: &self, encoding: encoding)
    }

    public mutating func decodeExplicit<T: CustomBinaryDecodable>(encoding: T.Encoding?) throws -> T {
        try T(from: &self, encoding: encoding)
    }

    /// Sets a limit on the number of bytes to decode before issuing a ``BinaryDecodingError/limitExceeded``.
    public mutating func setLimit(_ limit: Int) {
        self.limit = limit
    }

    /// Resets the limit to none.
    public mutating func resetLimit() {
        limit = .none
    }

    /// Sets a checkpoint to which we might want to revert if something fails.
    ///
    /// To revert use ``revert()``.
    public mutating func setCheckpoint() {
        checkpoint = offset
        checkpointLimit = limit
    }

    /// Clears a previously set checkpoint.
    public mutating func clearCheckpoint() {
        checkpoint = .none
        checkpointLimit = .none
    }

    /// Rolls back the offset and the limit to the values when ``setCheckpoint()`` was last called.
    public mutating func revert() {
        guard let checkpoint else { return }
        offset = checkpoint
        limit = checkpointLimit
        clearCheckpoint()
    }

    /// Peeks into the next _n_ bytes to be decoded without advancing the internal offset.
    public func peek(_ count: Int) -> Data {
        Data(data[offset ..< offset + 2])
    }

    public func peek() -> UInt8? {
        guard offset < data.count else {
            return .none
        }
        return data[offset]
    }

    /// Decodes a primitive type value.
    mutating func decodePrimitive<T: BinaryEncodingPrimitive>() throws -> T {
        let count = MemoryLayout<T>.size
        if let limit {
            if count <= limit { self.limit = limit - count }
            else { throw BinaryDecodingError.limitExceeded }
        }

        let nextOffset = offset + count
        guard nextOffset <= data.count else {
            throw BinaryDecodingError.outOfRange
        }

        let value = data.withUnsafeBytes {
            $0.loadUnaligned(fromByteOffset: offset, as: T.self)
        }
        offset = nextOffset
        return value
    }
}
