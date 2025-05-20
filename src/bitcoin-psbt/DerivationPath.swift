import Foundation
import BitcoinCrypto

public struct DerivationPath: Equatable, Sendable {

    init(fingerprint: Int, indices: [Int]) {
        self.fingerprint = fingerprint
        self.indices = indices
    }

    public let fingerprint: Int
    public let indices: [Int]
}

extension DerivationPath: CustomBinaryCodable {

    public enum DecodingError: Error {
        case invalidFingerprint, invalidIndex
    }

    public init(from decoder: inout BinaryDecoder, encoding: Never?) throws(DecodingError) {
        guard let fingerprintRaw = try? decoder.decode() as UInt32 else {
            throw .invalidFingerprint
        }
        fingerprint = Int(fingerprintRaw)
        guard let indicesRaw: [UInt32] = try? decoder.decodeArray() else {
            throw .invalidIndex
        }
        indices = indicesRaw.map { Int($0) }
    }

    public func encodingSize(_ counter: inout BinaryEncodingSizeCounter, encoding: Never?) {
        counter.count(UInt32(fingerprint))
        counter.countArray(indices.map { UInt32($0) })
    }

    public func encode(to encoder: inout BinaryEncoder, encoding: Never?) {
        encoder.encode(UInt32(fingerprint))
        encoder.encodeArray(indices.map { UInt32($0) })
    }
}
