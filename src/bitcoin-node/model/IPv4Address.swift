import Foundation

fileprivate let length = 4

struct IPv4Address: Equatable, CustomStringConvertible, CustomDebugStringConvertible, ExpressibleByStringLiteral {

    var description: String {
        "\(rawValue[0]).\(rawValue[1]).\(rawValue[2]).\(rawValue[3])"
    }

    var debugDescription: String {
        "IPv4Address(\(description))"
    }

    init(_ rawValue: Data) {
        let rawValue1 = if rawValue.count > length {
            rawValue[..<rawValue.startIndex.advanced(by: length)]
        } else {
            rawValue
        }
        let rawValue2 = if rawValue1.count < length {
            Data(repeating: 0, count: length - rawValue1.count) + rawValue1
        } else {
            rawValue1
        }
        self.rawValue = rawValue2
    }

    init(stringLiteral: String) {
        var parts = stringLiteral.split(separator: ".").map { UInt8($0) ?? 0 }
        parts += [UInt8](repeating: 0, count: max(0, length - parts.count))
        self.init(Data(parts))
    }

    private(set) var rawValue: Data

    static let loopback = Self(Data([0x7f, 0x00, 0x00, 0x01]))
    static let empty = Self(Data([0x00, 0x00, 0x00, 0x00]))
}
