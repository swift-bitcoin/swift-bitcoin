import Foundation
import BinaryParsing
import BitcoinCrypto
import BitcoinBase

/// A reference to an unspent transaction output (aka _UTXO_).
public struct UnspentOutput: Equatable, Sendable {

    let out: TransactionOutput
    let height: Int
    let isCoinbase: Bool

    public init(_ out: TransactionOutput, height: Int = Self.mempoolHeight, isCoinbase: Bool = false) {
        precondition(height > 0 && height <= Self.mempoolHeight)
        self.out = out
        self.height = height
        self.isCoinbase = isCoinbase
    }

    var isMempool: Bool {
        height == Self.mempoolHeight
    }
    public static let mempoolHeight = 0x7fffffff
}

extension UnspentOutput: BinaryCodable {

    public init(parsing input: inout ParserSpan, format: Never?) throws {
        // Reading isCoinbase first to allow for a null marker (UInt8.max) without possible conflict of values
        isCoinbase = try UInt8(parsing: &input) != 0
        out = try .init(parsing: &input)
        height = try Int(UInt32(parsingLittleEndian: &input))
    }

    public func countBytes(into counter: inout BinarySizeCounter, format: Never?) {
        counter.countSize(1) // Bool -> UInt8
        counter.count(out)
        counter.count(UInt32.self)
    }

    public func encode(into out: inout OutputRawSpan, format: Never?) throws {
        // Saving isCoinbase first to allow for a null marker (UInt8.max) without possible conflict of values
        out.append(isCoinbase ? 1 : 0) // TODO: Check this is how encoder was handling boolens (UInt8)
        try self.out.encode(into: &out)
        out.append(UInt32(height), as: UInt32.self, .littleEndian)
    }
}

extension Optional: BinaryCodable where Wrapped == UnspentOutput {

    public init(parsing input: inout ParserSpan, format: Never?) throws {
        let previousRange = input.parserRange
        let noneMarker = try UInt8(parsing: &input)
        if noneMarker == .max {
            self = nil
        } else {
            try input.seek(toRange: previousRange)
            self = try UnspentOutput(parsing: &input)
        }
    }

    public func countBytes(into counter: inout BinarySizeCounter, format: Never?) {
        if let self {
            counter.count(self)
        } else {
            counter.countSize(1)
        }
    }

    public func encode(into out: inout OutputRawSpan, format: Never?) throws {
        if let self {
            try self.encode(into: &out)
        } else {
            out.append(UInt8.max)
        }
    }
}
