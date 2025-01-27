import Foundation
import BitcoinCrypto

/// The version of a ``BitcoinTx``.
///
/// Version 2 transactions enable use of relative lock times.
public struct TxVersion: Equatable, Comparable, Sendable {

    private init(_ versionValue: Int) {
        self.versionValue = versionValue
    }

    init(_ rawValue: UInt32) {
        self.init(Int(rawValue))
    }

    public let versionValue: Int

    var rawValue: UInt32 {
        UInt32(versionValue)
    }

    public static func < (lhs: TxVersion, rhs: TxVersion) -> Bool {
        lhs.versionValue < rhs.versionValue
    }

    /// Transaction version 1.
    public static let v1 = Self(1)

    /// BIP68 - Transaction version 2.
    public static let v2 = Self(2)
}

/// Binary data extensions.
extension TxVersion: BinaryCodable {
    public init(from decoder: inout BinaryDecoder) throws(BinaryDecodingError) {
        let rawValue: UInt32 = try decoder.decode()
        self.init(Int(rawValue))
    }

    public func encode(to encoder: inout BinaryEncoder) {
        encoder.encode(UInt32(versionValue))
    }

    public func encodingSize(_ counter: inout BinaryEncodingSizeCounter) {
        counter.count(UInt32.self)
    }
}

