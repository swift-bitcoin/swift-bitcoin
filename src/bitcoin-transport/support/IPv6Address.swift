import Foundation

fileprivate let length = 16

public struct IPv6Address: Equatable, Sendable, CustomStringConvertible, CustomDebugStringConvertible, ExpressibleByStringLiteral {

    public var description: String {
        var words = words
        var longestChainIndex = -1
        var longestChainLength = -1
        var currentChainIndex = -1
        var currentChainLength = -1
        for i in words.indices {
            let word = words[i]
            if word == 0 {
                if currentChainIndex == -1 {
                    currentChainIndex = i
                    currentChainLength = 1
                } else {
                    currentChainLength += 1
                }
            } else if currentChainIndex != -1 {
                if currentChainLength > longestChainLength {
                    longestChainIndex = currentChainIndex
                    longestChainLength = currentChainLength
                }
                currentChainIndex = -1
                currentChainLength = -1
            }
        }
        if longestChainIndex != -1 {
            words = .init(words.prefix(upTo: longestChainIndex) + words.suffix(from: longestChainIndex + longestChainLength))
        }
        var description = ""
        for i in words.indices {
            let word = words[i]
            let isFirst = i == words.startIndex
            let isLast = i == words.endIndex - 1
            if longestChainIndex != -1 && longestChainIndex == i {
                if isFirst || isLast {
                    description += "::"
                } else {
                    description += ":"
                }
            }
            if !isFirst {
                description += ":"
            }
            description += String(word, radix: 16)
        }
        return description
    }

    public var debugDescription: String {
        "IPv6Address(\(description))"
    }

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

    public init(_ words: [UInt16]) {
        var bytes = [UInt8]()
        for word in words {
            bytes.append(UInt8(word >> 8))
            bytes.append(UInt8((word << 8) >> 8))
        }
        self.init(Data(bytes))
    }

    public init(stringLiteral: String) {
        self.init(stringLiteral)
    }

    public init(_ stringLiteral: String) {
        let halfs = stringLiteral.split(separator: "::")
        let partsA = halfs.count < 1 ? [UInt16]() : halfs[0].split(separator: ":").map { UInt16($0, radix: 16) ?? 0 }
        let partsB = halfs.count < 2 ? [UInt16]() : halfs[1].split(separator: ":").map { UInt16($0, radix: 16) ?? 0 }
        let zeros = [UInt16](repeating: 0, count: max(0, 8 - (partsA.count + partsB.count)))
        let parts = if stringLiteral.hasPrefix("::") {
            zeros + partsA
        } else if stringLiteral.hasSuffix("::") {
            partsA + zeros
        } else {
            partsA + zeros + partsB
        }
        self.init(parts)
    }

    private(set) var rawValue: Data

    public var words: [UInt16] {
        var words = [UInt16]()
        for i in stride(from: rawValue.startIndex, to: rawValue.endIndex, by: 2) {
            let word = (UInt16(rawValue[i]) << 8) + UInt16(rawValue[i + 1])
            words.append(word)
        }
        return words
    }

    public static let loopback = Self(Data([0x01]))
    public static let ipV4Loopback = Self(IPv4Address.loopback)
    public static let unspecified = Self(Data(repeating: 0x00, count: 16))

    /// Attempts to produce an address from a host string.
    static func fromHost(_ host: String) -> Self {
        let asIPv6 = IPv6Address(stringLiteral: host)
        let asIPv4 = IPv4Address(stringLiteral: host)
        return if asIPv6 != .unspecified {
            asIPv6
        } else if asIPv4 != .empty {
            .init(asIPv4)
        } else {
            .unspecified
        }
    }
}
