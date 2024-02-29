import Foundation

fileprivate let length = 16

struct IPv6Address: Equatable {

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

    /// https://en.wikipedia.org/wiki/IPv6#IPv4-mapped_IPv6_addresses
    init(_ ipv4: IPv4Address) {
        self.init(Data(repeating: 0xff, count: 2) + ipv4.rawValue)
    }

    private(set) var rawValue: Data

    static let loopback = Self(Data([0x01]))
    static let ipV4Loopback = Self(IPv4Address.loopback)
    static let empty = Self(Data(repeating: 0x00, count: 16))
}
