import Foundation
import BitcoinCrypto

public struct SighashType: Equatable, Sendable {

    init(rawValue: Int32) {
        self.rawValue = rawValue
    }

    init(unchecked: UInt8) {
        self.init(rawValue: Int32(unchecked))
    }

    init?(_ value: UInt8) {
        self.init(unchecked: value)
        if !isDefined { return nil }
    }

    private let rawValue: Int32

    public var value: UInt8 {
        withUnsafeBytes(of: rawValue) { $0[0] }
    }

    public var isAll: Bool {
        value & Self.maskAnyCanPay == Self.sighashAll
    }

    public var isNone: Bool {
        value & Self.maskAnyCanPay == Self.sighashNone
    }

    public var isSingle: Bool {
        value & Self.maskAnyCanPay == Self.sighashSingle
    }

    public var isAnyCanPay: Bool {
        value & Self.sighashAnyCanPay == Self.sighashAnyCanPay
    }

    public var hasAnyCanPay: Bool {
        value & Self.sighashAnyCanPay != 0
    }

    var isDefined: Bool {
        switch value & ~Self.sighashAnyCanPay {
        case Self.sighashAll, Self.sighashNone, Self.sighashSingle: true
        default: false
        }
    }

    private static let sighashAll = UInt8(0x01)
    private static let sighashNone = UInt8(0x02)
    private static let sighashSingle = UInt8(0x03)
    private static let sighashAnyCanPay = UInt8(0x80)
    private static let maskAnyCanPay = UInt8(0x1f)

    public static let all = Self(unchecked: Self.sighashAll)
    public static let none = Self(unchecked: Self.sighashNone)
    public static let single = Self(unchecked: Self.sighashSingle)
    public static let allAnyCanPay = Self(unchecked: Self.sighashAll | Self.sighashAnyCanPay)
    public static let noneAnyCanPay = Self(unchecked: Self.sighashNone | Self.sighashAnyCanPay)
    public static let singleAnyCanPay = Self(unchecked: Self.sighashSingle | Self.sighashAnyCanPay)
}

extension SighashType: BinaryEncodable {

    public func encode(to encoder: inout BinaryEncoder) {
        encoder.encode(value)
    }

    public func encode32(to encoder: inout BinaryEncoder) {
        encoder.encode(rawValue)
    }

    public func encodingSize(_ counter: inout BinaryEncodingSizeCounter) {
        counter.count(value)
    }

    public func encodingSize32(_ counter: inout BinaryEncodingSizeCounter) {
        counter.count(rawValue)
    }

    var data32: Data {
        var counter = BinaryEncodingSizeCounter()
        encodingSize32(&counter)
        var encoder = BinaryEncoder(counter)
        encode32(to: &encoder)
        return encoder.data
    }
}

/// BIP341: Used to represent the `default` signature hash type.
extension Optional where Wrapped == SighashType {

    var data: Data {
        if case let .some(wrapped) = self { wrapped.binaryData } else { Data([0x00]) }
    }
}
