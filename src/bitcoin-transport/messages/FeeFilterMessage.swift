import BinaryParsing
import BitcoinBase
import BitcoinCrypto
import Foundation

/// BIP133 - https://github.com/bitcoin/bips/blob/master/bip-0133.mediawiki
public struct FeeFilterMessage: Equatable {
    /// Satoshis per virtual byte.
    public let feeRate: Amount

    static let size = MemoryLayout<UInt64>.size
}

extension FeeFilterMessage: BinaryCodable {
    public init(parsing input: inout ParserSpan, format: Never?) throws {
        feeRate = Amount(try UInt64(parsingLittleEndian: &input))
    }

    public func countBytes(into counter: inout BinarySizeCounter, format: Never?) {
        counter.count(UInt64.self)
    }

    public func encode(into out: inout OutputRawSpan, format: Never?) throws {
        out.append(UInt64(feeRate), as: UInt64.self, .littleEndian)
    }
}
