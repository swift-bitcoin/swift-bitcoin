import Foundation

public protocol BinaryTrivial {}
extension Int: BinaryTrivial {}
extension UInt: BinaryTrivial {}
extension Int8: BinaryTrivial {}
extension UInt8: BinaryTrivial {}
extension Int16: BinaryTrivial {}
extension UInt16: BinaryTrivial {}
extension Int32: BinaryTrivial {}
extension UInt32: BinaryTrivial {}
extension Int64: BinaryTrivial {}
extension UInt64: BinaryTrivial {}
// extension Array: BinaryTrivial where Element: BinaryTrivial {}

public struct BinaryDecoder {

    public enum Error: Swift.Error {
        case outOfRange, limitExceeded
    }

    private var data: Data
    private var offset = 0
    private var limit = Int?.none

    public init<D: DataProtocol>(_ data: D) {
        self.data = Data(data)
    }

    public mutating func setLimit(_ limit: Int) {
        self.limit = limit
    }

    public mutating func resetLimit() {
        limit = .none
    }

    public mutating func take<E>() throws(Error) -> Array<E> where E: BinaryTrivial {
        let count: VarInt = try take()
        var ret = [E]()
        for _ in 0 ..< count.value {
            ret.append(try take())
        }
        return ret
    }

    public mutating func take<T: BinaryTrivial>() throws(Error) -> T {
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

    public mutating func take(_ count: Int? = .none, byteSwapped: Bool = false) throws(Error) -> Data {
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

    public mutating func take<T: BinaryDecodable>() throws(Error) -> T {
        try T(from: &self)
    }
}
