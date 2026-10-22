import Foundation
import BinaryParsing
import BitcoinCrypto

public struct PingMessage: Equatable, Sendable {

    init() {
        self.nonce = .random(in: UInt64.min ... UInt64.max)
    }

    public let nonce: UInt64
}

extension PingMessage: BinaryCodable {

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
