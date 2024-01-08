import Foundation

fileprivate let length = 4

public struct IPv4Address: Equatable {

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

    public private(set) var rawValue: Data

    public static let loopback = Self(Data([0xff, 0x00, 0x00, 0x01]))
}
