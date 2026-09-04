import Foundation
import BinaryParsing
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

    public init(parsing input: inout ParserSpan, format: Never?) throws(DecodingError) {
        guard let fingerprintRaw = try? UInt32(parsingLittleEndian: &input) else {
            throw .invalidFingerprint
        }
        fingerprint = Int(fingerprintRaw)
        var indicesRaw = [UInt32]()
        while !input.isEmpty {
            let indexElement: UInt32
            do {
                indexElement = try .init(parsingLittleEndian: &input)
            } catch {
                throw .invalidIndex
            }
            indicesRaw.append(indexElement)

        }
        indices = indicesRaw.map { Int($0) }
    }

    public func countBytes(into counter: inout BinarySizeCounter, format: Never?) {
        counter.count(UInt32.self)
        counter.countSize(MemoryLayout<UInt32>.size * indices.count)
    }

    public func encode(into out: inout OutputRawSpan, format: Never?) throws {
        out.append(UInt32(fingerprint), as: UInt32.self, .littleEndian)
        for i in indices.map(UInt32.init) {
            out.append(i, as: UInt32.self, .littleEndian)
        }
    }
}
