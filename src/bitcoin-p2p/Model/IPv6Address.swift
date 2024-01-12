import Foundation

fileprivate let length = 16

public struct IPv6Address: Equatable {

    public init(_ rawValue: Data) {
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

    /// https://en.wikipedia.org/wiki/IPv6#IPv4-mapped_IPv6_addresses
    public init(_ ipv4: IPv4Address) {
        self.init(Data(repeating: 0xff, count: 2) + ipv4.rawValue)
    }

    public private(set) var rawValue: Data

    public static let loopback = Self(Data([0x01]))
}
