import Foundation
import BinaryParsing
import BitcoinCrypto

public struct SighashType: Equatable, Sendable {

    init(rawValue: Int32) {
        self.rawValue = rawValue
    }

    init(unchecked: UInt8) {
        self.init(rawValue: Int32(unchecked))
    }

    public init?(_ value: UInt8) {
        self.init(unchecked: value)
        if !isDefined { return nil }
    }

    private let rawValue: Int32

    public var value: UInt8 {
        let data = Data(capacity: MemoryLayout<Int32>.size) { out in
            out.append(rawValue, as: Int32.self, .littleEndian)
        }
        return data[0]
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

extension SighashType: BinaryCodable {

    public enum BinaryFormat: Equatable, Sendable {
        case fullLength
    }

    public enum DecodingError: Error {
        case invalidData, undefinedSighashType
    }

    public init(parsing input: inout ParserSpan, format: BinaryFormat?) throws(DecodingError) {
        switch format {
        case nil:
            let value: UInt8
            do {
                value = try UInt8(parsing: &input)
            } catch {
                throw .invalidData
            }
            guard let maybeSelf = Self(value) else {
                throw .undefinedSighashType
            }
            self = maybeSelf
        case .some(let format):
            switch format {
            case .fullLength:
                let rawValue: Int32
                do {
                    rawValue = try Int32(parsingLittleEndian: &input)
                } catch {
                    throw .invalidData
                }
                let maybeSelf = Self(rawValue: rawValue)
                guard maybeSelf.isDefined else {
                    throw .undefinedSighashType
                }
                self = maybeSelf
            }
        }
    }

    public func countBytes(into counter: inout BinarySizeCounter, format: BinaryFormat?) {
        switch format {
        case nil: counter.countSize(1)
        case .some(let format):
            switch format {
            case .fullLength:
                counter.count(Int32.self)
            }
        }
    }

    public func encode(into out: inout OutputRawSpan, format: BinaryFormat?) throws {
        switch format {
        case nil: out.append(value)
        case .some(let format):
            switch format {
            case .fullLength:
                out.append(rawValue, as: Int32.self, .littleEndian)
            }
        }
    }
}

/// BIP341: Used to represent the `default` signature hash type.
extension Optional where Wrapped == SighashType {

    var data: Data {
        if case let .some(wrapped) = self { wrapped.data } else { Data([0x00]) }
    }
}
