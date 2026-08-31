import Foundation
import BitcoinCrypto

public struct DerivationPath: Equatable, Sendable {

    package init(fingerprint: Int, indices: [Int], harden: [Bool]? = nil) {
        let resolvedHarden: [Bool]
        if let harden {
            precondition(harden.count == indices.count)
            resolvedHarden = harden
        } else {
            resolvedHarden = .init(repeating: false, count: indices.count)
        }
        self.fingerprint = fingerprint
        self.indices = zip(indices, resolvedHarden).map { i, h in
            precondition(i < (1 << 31))
            return h ? (1 << 31) + i : i
        }
    }

    public let fingerprint: Int
    public let indices: [Int]
}

extension DerivationPath: BinaryCodable {

    public enum DecodingError: Error {
        case invalidFingerprint, invalidIndex
    }

    public init(from decoder: inout BinaryDecoder, format: Never?) throws(DecodingError) {
        guard let fingerprintRaw = try? decoder.decode() as UInt32 else {
            throw .invalidFingerprint
        }
        fingerprint = Int(fingerprintRaw)
        guard let indicesRaw: [UInt32] = try? decoder.decodeArray() else {
            throw .invalidIndex
        }
        indices = indicesRaw.map { Int($0) }
    }

    public func countBytes(into counter: inout BinarySizeCounter, format: Never?) {
        counter.count(UInt32(fingerprint))
        counter.countArray(indices.map { UInt32($0) })
    }

    public func encode(into encoder: inout BinaryEncoder, format: Never?) {
        encoder.encode(UInt32(fingerprint))
        encoder.encodeArray(indices.map { UInt32($0) })
    }
}
