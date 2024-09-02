import Foundation
import BitcoinCrypto

public struct SighashType: Sendable {

    init?(_ value: UInt8) {
        self.value = value
        if !isDefined { return nil }
    }

    public let value: UInt8

    var isAll: Bool {
        value & Self.maskAnyCanPay == Self.sighashAll
    }

    var isNone: Bool {
        value & Self.maskAnyCanPay == Self.sighashNone
    }

    var isSingle: Bool {
        value & Self.maskAnyCanPay == Self.sighashSingle
    }

    var isAnyCanPay: Bool {
        value & Self.sighashAnyCanPay == Self.sighashAnyCanPay
    }

    var isDefined: Bool {
        switch value & ~Self.sighashAnyCanPay {
        case Self.sighashAll, Self.sighashNone, Self.sighashSingle: true
        default: false
        }
    }

    static func splitSchnorrSignature(_ extendedSignature: Data) throws -> (Data, SighashType?) {
        var sigTmp = extendedSignature
        let sighashType: SighashType?
        if sigTmp.count == Signature.extendedSchnorrSignatureLength, let rawValue = sigTmp.popLast(), let maybeHashType = SighashType(rawValue) {
            // If the sig is 64 bytes long, return Verify(q, hashTapSighash(0x00 || SigMsg(0x00, 0)), sig), where Verify is defined in BIP340.
            sighashType = maybeHashType
        } else if sigTmp.count == Signature.schnorrSignatureLength {
            // If the sig is 65 bytes long, return sig[64] ≠ 0x00 and Verify(q, hashTapSighash(0x00 || SigMsg(sig[64], 0)), sig[0:64]).
            sighashType = SighashType?.none
        } else {
            // Otherwise, fail.
            throw ScriptError.invalidSchnorrSignatureFormat
        }
        let signature = sigTmp
        return (signature, sighashType)
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
extension Optional where Wrapped == SighashType {

    private var assumed: SighashType { .all }

    var isNone: Bool {
        if case let .some(wrapped) = self {
            return wrapped.isNone
        }
        return assumed.isNone
    }

    var isAll: Bool {
        if case let .some(wrapped) = self {
            return wrapped.isAll
        }
        return assumed.isAll
    }

    var isSingle: Bool {
        if case let .some(wrapped) = self {
            return wrapped.isSingle
        }
        return assumed.isSingle
    }

    var isAnyCanPay: Bool {
        if case let .some(wrapped) = self {
            return wrapped.isAnyCanPay
        }
        return assumed.isAnyCanPay
    }
}

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
        if case let .some(wrapped) = self {
            return wrapped.data
        }
        return Data([0x00])
    }
}
