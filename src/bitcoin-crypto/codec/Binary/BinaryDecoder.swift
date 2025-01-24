import Foundation

public struct BinaryDecoder {

    public init<D: DataProtocol>(_ data: D) {
        self.data = Data(data)
    }

    private var data: Data
    private var offset = 0
    private var limit = Int?.none
    private var checkpoint = Int?.none
    private var checkpointLimit = Int?.none

    public mutating func take(_ count: Int? = .none, byteSwapped: Bool = false) throws(BinaryDecodingError) -> Data {
        let remaining = data.count - offset
        let count = if let count { count }
                    else if let limit { limit }
                    else { remaining }

        if let limit {
            if count <= limit { self.limit = limit - count }
            else { throw .limitExceeded }
        }

        let nextOffset = offset + count
        guard nextOffset <= data.count else {
            throw .outOfRange
        }

        var value = data[offset ..< nextOffset]
        if byteSwapped { value.reverse() }
        offset = nextOffset
        return Data(value)
    }

    public mutating func take<T: BinaryDecodable>() throws(BinaryDecodingError) -> T {
        try T(from: &self)
    }

    public mutating func setLimit(_ limit: Int) {
        self.limit = limit
    }

    public mutating func resetLimit() {
        limit = .none
    }

    public mutating func setCheckpoint() {
        checkpoint = offset
        checkpointLimit = limit
    }

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

    mutating func takePrimitive<T: BinaryEncodingPrimitive>() throws(BinaryDecodingError) -> T {
        let count = MemoryLayout<T>.size
        if let limit {
            if count <= limit { self.limit = limit - count }
            else { throw .limitExceeded }
        }

        let nextOffset = offset + count
        guard nextOffset <= data.count else {
            throw .outOfRange
        }

        let value = data.withUnsafeBytes {
            $0.loadUnaligned(fromByteOffset: offset, as: T.self)
        }
        offset = nextOffset
        return value
    }
}
