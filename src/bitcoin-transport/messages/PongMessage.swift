import Foundation
import BinaryParsing
import BitcoinCrypto

public struct PongMessage: Equatable, Sendable {

    init(nonce: UInt64) {
        self.nonce = nonce
    }

    public let nonce: UInt64

    static let size = MemoryLayout<UInt64>.size
}

extension PongMessage: BinaryCodable {

    public init(parsing input: inout ParserSpan, format: Never?) throws {
        nonce = try .init(parsingLittleEndian: &input)
    }

    public func countBytes(into counter: inout BinarySizeCounter, format: Never?) {
        counter.count(UInt64.self)
    }

    public func encode(into out: inout OutputRawSpan, format: Never?) throws {
        out.append(nonce, as: UInt64.self, .littleEndian)
    }
}
