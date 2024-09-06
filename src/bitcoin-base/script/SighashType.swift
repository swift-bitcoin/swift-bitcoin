import Foundation
import BitcoinCrypto

public struct SighashType: Equatable, Sendable {

    init?(_ value: UInt8) {
        self.value = value
        if !isDefined { return nil }
    }

    public let value: UInt8

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

    public static let all = Self(Self.sighashAll)!
    public static let none = Self(Self.sighashNone)!
    public static let single = Self(Self.sighashSingle)!
    public static let allAnyCanPay = Self(Self.sighashAll | Self.sighashAnyCanPay)!
    public static let noneAnyCanPay = Self(Self.sighashNone | Self.sighashAnyCanPay)!
    public static let singleAnyCanPay = Self(Self.sighashSingle | Self.sighashAnyCanPay)!
}

/// BIP341: Used to represent the `default` signature hash type.
//extension Optional where Wrapped == SighashType {
//
//    private var assumed: SighashType { .all }
//
//    var isNone: Bool {
//        if case let .some(wrapped) = self {
//            return wrapped.isNone
//        }
//        return assumed.isNone
//    }
//
//    var isAll: Bool {
//        if case let .some(wrapped) = self {
//            return wrapped.isAll
//        }
//        return assumed.isAll
//    }
//
//    var isSingle: Bool {
//        if case let .some(wrapped) = self {
//            return wrapped.isSingle
//        }
//        return assumed.isSingle
//    }
//
//    var isAnyCanPay: Bool {
//        if case let .some(wrapped) = self {
//            return wrapped.isAnyCanPay
//        }
//        return assumed.isAnyCanPay
//    }
//}

extension SighashType {

    init?(_ data: Data) {
        guard let value = data.first else { return nil }
        self.value = value
    }

    var data: Data {
        Data(value: value)
    }

    var data32: Data {
        Data(value: UInt32(value))
    }
}

extension Optional where Wrapped == SighashType {

    var data: Data {
        return if case let .some(wrapped) = self { wrapped.data } else { Data([0x00]) }
    }
}
