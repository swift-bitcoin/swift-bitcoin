import Foundation

/// An object that decodes values from a native binary format into in-memory representations.
public struct BinaryDecoder {

    public init<D: DataProtocol>(_ data: D) {
        self.data = Data(data)
    }

    private var data: Data
    private var offset = 0
    private var limits = [Int]()
    private var checkpoint = Int?.none
    private var checkpointLimit = Int?.none

    private var limit: Int? {
        get {
            limits.last
        }
        set {
            if let newValue {
                if limits.isEmpty {
                    limits.append(newValue)
                } else {
                    limits[limits.endIndex - 1] = newValue
                }
            } else {
                if !limits.isEmpty {
                    limits.removeLast()
                }
            }
        }
    }

    /// Decodes data which may appear prefixed by its length as a variable integer.
    public mutating func decode(variable: Bool, byteSwapped: Bool = false) throws -> Data {
        if variable {
            let varInt: VarInt = try decode()
            return try decode(varInt.value, byteSwapped: byteSwapped)
        }
        return try decode(byteSwapped: byteSwapped)
    }

    /// Decodes data of the specified length or until there are no more bytes available.
    @discardableResult public mutating func decode(_ count: Int? = nil, byteSwapped: Bool = false) throws -> Data {
        let remaining = data.count - offset
        let count = if let count { count }
                    else if let limit { limit }
                    else { remaining }

        if let limit {
            if count <= limit {
                self.limit = limit - count
            } else {
                throw BinaryDecodingError.limitExceeded
            }
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

    public mutating func decodeArray<T: BinaryEncodingPrimitive>(count: Int? = nil) throws -> [T] {
        let elementSize = MemoryLayout<T>.size
        let userByteCount = if let count { count * elementSize } else { Int?.none }
        let remaining = data.count - offset
        let byteCount = if let userByteCount { userByteCount }
                    else if let limit { limit }
                    else { remaining }

        guard byteCount % elementSize == 0 else {
            throw BinaryDecodingError.outOfRange
        }

        if let limit {
            if byteCount <= limit { self.limit = limit - byteCount }
            else { throw BinaryDecodingError.limitExceeded }
        }

        let nextOffset = offset + byteCount
        guard nextOffset <= data.count else {
            throw BinaryDecodingError.outOfRange
        }

        let count = count ?? byteCount / elementSize

        var result = [T]()
        for _ in 0 ..< count {
            result.append(try decode())
        }

        return result
        // offset = nextOffset
    }

    /// Sets a limit on the number of bytes to decode before issuing a ``BinaryDecodingError/limitExceeded``.
    public mutating func setLimit(_ limit: Int) {
        limits.append(limit)
    }

    /// Resets the limit to none.
    public mutating func resetLimit() {
        limits.removeLast()
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
        checkpoint = nil
        checkpointLimit = nil
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
        let min = min(data.endIndex, offset + count)
        return Data(data[offset ..< min])
    }

    public func peek() -> UInt8? {
        guard offset < data.count else {
            return nil
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
