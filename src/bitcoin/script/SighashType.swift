import Foundation

public struct SighashType {

    init?(_ data: Data) {
        guard let value8 = data.first else {
            return nil
        }
        value = Int(value8)
    }

    let value: Int

    var value8: UInt8 { .init(value) }

    var data: Data {
        withUnsafeBytes(of: value8) { Data($0) }
    }

    var data32: Data {
        withUnsafeBytes(of: UInt32(value)) { Data($0) }
    }

    var isAll: Bool {
        value8 & Self.maskAnyCanPay == Self.sighashAll
    }

    var isNone: Bool {
        value8 & Self.maskAnyCanPay == Self.sighashNone
    }

    var isSingle: Bool {
        value8 & Self.maskAnyCanPay == Self.sighashSingle
    }

    var isAnyCanPay: Bool {
        value8 & Self.sighashAnyCanPay == Self.sighashAnyCanPay
    }

    var isDefined: Bool {
        switch value8 & ~Self.sighashAnyCanPay {
            case Self.sighashAll, Self.sighashNone, Self.sighashSingle: true
            default: false
        }
    }

    static let sighashAll = UInt8(0x01)
    static let sighashNone = UInt8(0x02)
    static let sighashSingle = UInt8(0x03)
    static let sighashAnyCanPay = UInt8(0x80)
    static let maskAnyCanPay = UInt8(0x1f)
}
