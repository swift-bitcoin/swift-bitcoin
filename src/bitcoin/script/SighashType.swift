import Foundation

public enum SighashType: UInt8 {
    case all = 0x01, none = 0x02, single = 0x03, allAnyCanPay = 0x81, noneAnyCanPay = 0x82, singleAnyCanPay = 0x83

    init?(_ uInt32: UInt32) {
        self.init(rawValue: UInt8(uInt32))
    }

    var isNone: Bool {
        self == .none || self == .noneAnyCanPay
    }

    var isAll: Bool {
        self == .all || self == .allAnyCanPay
    }

    var isSingle: Bool {
        self == .single || self == .singleAnyCanPay
    }

    var isAnyCanPay: Bool {
        self == .allAnyCanPay || self == .noneAnyCanPay || self == .singleAnyCanPay
    }

    var data: Data {
        withUnsafeBytes(of: rawValue) { Data($0) }
    }

    var data32: Data {
        withUnsafeBytes(of: UInt32(rawValue)) { Data($0) }
    }
}
