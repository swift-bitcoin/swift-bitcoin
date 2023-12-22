import Foundation

// MARK: - Serialization helper functions

/// Helper functions for serialization.
extension Data {

    /// Serializes a value into raw bytes and appends the result.
    mutating func addBytes<T>(of value: T) {
        self.append(Swift.withUnsafeBytes(of: value) { Data($0) })
    }
}

// MARK: - Hexadecimal encoding/decoding

public extension Data {

    /// Create instance from string containing hex digits.
    init?(hex: String) {
        guard let regex = try? NSRegularExpression(pattern: "([0-9a-fA-F]{2})", options: []) else {
            return nil
        }
        let range = NSRange(location: 0, length: hex.count)
        let bytes = regex.matches(in: hex, options: [], range: range)
            .compactMap { Range($0.range(at: 1), in: hex) }
            .compactMap { UInt8(hex[$0], radix: 16) }
        self.init(bytes)
    }
}

public extension DataProtocol {

    /// Hexadecimal (Base-16) string representation of data.
    var hex: String {
        map { String(format: "%02x", $0) }.joined()
    }
}

// MARK: - Variable Integer (Compact Integer)

extension Data {

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

extension UInt64 {

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

extension Data {

    init?(varLenData: Data) {
        var data = varLenData
        guard let contentLen = data.varInt else { return nil }
        data = data.dropFirst(contentLen.varIntSize)
        self = data[..<(data.startIndex + Int(contentLen))]
    }

    var varLenData: Data {
        Data(varInt: UInt64(count)) + self
    }

    /// Memory size as variable length byte array (array prefixed with its element count as compact integer).
    var varLenSize: Int {
        UInt64(count).varIntSize + count
    }
}

extension Array where Element == Data {

    /// Memory size as multiple variable length arrays.
    var varLenSize: Int {
        reduce(0) { $0 + $1.varLenSize }
    }
}
