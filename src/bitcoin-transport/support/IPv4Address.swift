import Foundation

fileprivate let length = 4

public struct IPv4Address: Equatable, Sendable, CustomStringConvertible, CustomDebugStringConvertible, ExpressibleByStringLiteral {

    public var description: String {
        "\(rawValue[0]).\(rawValue[1]).\(rawValue[2]).\(rawValue[3])"
    }

    public var debugDescription: String {
        "IPv4Address(\(description))"
    }

    public init(_ rawValue: Data) {
        let rawValue1 = rawValue.prefix(length)
        let rawValue2 = if rawValue1.count < length {
            Data(repeating: 0, count: length - rawValue1.count) + rawValue1
        } else {
            rawValue1
        }
        self.rawValue = rawValue2
    }

    public init(stringLiteral: String) {
        self.init(stringLiteral)
    }

    public init(_ stringLiteral: String) {
        var parts = stringLiteral.split(separator: ".").map { UInt8($0) ?? 0 }
        parts += [UInt8](repeating: 0, count: max(0, length - parts.count))
        self.init(Data(parts))
    }

    private(set) var rawValue: Data

    public static let loopback = Self(Data([0x7f, 0x00, 0x00, 0x01]))
    public static let empty = Self(Data([0x00, 0x00, 0x00, 0x00]))
}

extension IPv4Address {
    public static func parse(_ address: String) -> (host: String, port: Int?)? {
        let regex = /([\d\.]+)(\:(\d{1,5}))?/
        guard let _ = address.wholeMatch(of: regex) else {
            return nil
        }
        let matches = address.matches(of: regex)
        let host: String = matches[0].output.1.description
        let portString: String? = matches[0].output.3?.description
        let port: Int? = if let portString { Int(portString) } else { nil }
        return (host, port)
    }
}

#if canImport(Playgrounds)
import Playgrounds
#Playground {
    let ipv6 = "[::1]"
    let ipv6p = "[::1]:80"
    let ipv4 = "127.0.0.1"
    let ipv4p = "127.0.0.1:80"

    _ = IPv4Address.parse(ipv4)
    _ = IPv4Address.parse(ipv4p)
    _ = IPv4Address.parse(ipv6)
    _ = IPv4Address.parse(ipv6p)
}
#endif
