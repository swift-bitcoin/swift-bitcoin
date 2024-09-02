import Foundation

// MARK: - Serialization helper functions

/// Helper functions for serialization.
package extension Data {

    init<T>(value: T) {
        self.init(count: MemoryLayout.size(ofValue: value))
        addBytes(value)
    }

    /// Appends the value's binary contents.
    /// - Parameter value: The value whose bytes will be copied.
    mutating func appendBytes<T>(_ value: T) {
        Swift.withUnsafeBytes(of: value) {
            append(contentsOf: $0)
        }
    }

    /// Replaces bytes at `offset` with the binary contents of `value`.
    /// - Parameters:
    ///   - value: The source value whose bytes will be copied.
    ///   - offset: The destination position at which the source bytes will be copied.
    /// - Returns: An discardable offset right after the copied bytes to use when calling this method repeteadly.
    @discardableResult
    mutating func addBytes<T>(_ value: T, at offset: Self.Index? = .none) -> Self.Index {
        let offset = offset ?? startIndex
        let count = MemoryLayout.size(ofValue: value)
        precondition(self[offset...].count >= count)
        Swift.withUnsafePointer(to: value) { replaceSubrange(offset ..< offset.advanced(by: count), with: $0, count: count) }
        return offset.advanced(by: count)
    }

    @discardableResult
    mutating func addData<T: DataProtocol>(_ value: T, at offset: Self.Index? = .none) -> Self.Index {
        let offset = offset ?? startIndex
        let count = value.count
        precondition(self[offset...].count >= count)
        replaceSubrange(offset ..< offset.advanced(by: count), with: value)
        return offset.advanced(by: count)
    }
}

extension MutableDataProtocol {
    mutating func appendByte(_ byte: UInt64) {
        withUnsafePointer(to: byte.littleEndian, { self.append(contentsOf: UnsafeRawBufferPointer(start: $0, count: 8)) })
    }
}

// MARK: - Variable Integer (Compact Integer)

package extension Data {

    /// Converts a 64-bit integer into its compact integer representation – i.e. variable length data.
    init(varInt value: UInt64) {
        if value < 0xfd {
            var valueVar = UInt8(value)
            self.init(bytes: &valueVar, count: MemoryLayout.size(ofValue: valueVar))
        } else if value <= UInt16.max {
            self = Data([0xfd]) + Swift.withUnsafeBytes(of: UInt16(value)) { Data($0) }
        } else if value <= UInt32.max {
            self = Data([0xfe]) + Swift.withUnsafeBytes(of: UInt32(value)) { Data($0) }
        } else {
            self = Data([0xff]) + Swift.withUnsafeBytes(of: value) { Data($0) }
        }
    }

    /// Parses bytes interpreted as variable length – i.e. compact integer – data into a 64-bit integer.
    var varInt: UInt64? {
        guard let firstByte = first else {
            return .none
        }
        let tail = dropFirst()
        if firstByte < 0xfd {
            return UInt64(firstByte)
        }
        if firstByte == 0xfd {
            let value = tail.withUnsafeBytes {
                $0.loadUnaligned(as: UInt16.self)
            }
            return UInt64(value)
        }
        if firstByte == 0xfd {
            let value = tail.withUnsafeBytes {
                $0.loadUnaligned(as: UInt32.self)
            }
            return UInt64(value)
        }
        let value = tail.withUnsafeBytes {
            $0.loadUnaligned(as: UInt64.self)
        }
        return value
    }
}

package extension UInt64 {

    var varIntSize: Int {
        switch self {
        case 0 ..< 0xfd:
            return 1
        case 0xfd ... UInt64(UInt16.max):
            return 1 + MemoryLayout<UInt16>.size
        case UInt64(UInt16.max) + 1 ... UInt64(UInt32.max):
            return 1 + MemoryLayout<UInt32>.size
        case UInt64(UInt32.max) + 1 ... UInt64.max:
            return 1 + MemoryLayout<UInt64>.size
        default:
            preconditionFailure()
        }
    }
}

// MARK: - Variable length array

package extension Data {

    init?(varLenData: Data) {
        var data = varLenData
        guard let contentLen = data.varInt else { return nil }
        data = data.dropFirst(contentLen.varIntSize)
        self = data.prefix(Int(contentLen))
    }

    var varLenData: Data {
        Data(varInt: UInt64(count)) + self
    }

    /// Memory size as variable length byte array (array prefixed with its element count as compact integer).
    var varLenSize: Int {
        UInt64(count).varIntSize + count
    }
}

package extension Array where Element == Data {

    /// Memory size as multiple variable length arrays.
    var varLenSize: Int {
        reduce(0) { $0 + $1.varLenSize }
    }
}
