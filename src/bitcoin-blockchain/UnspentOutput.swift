import Foundation
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

    public init(from decoder: inout BinaryDecoder) throws {
        out = try decoder.decode()
        height = try decoder.decode()
        isCoinbase = try decoder.decode()
    }

    public func encode(to encoder: inout BinaryEncoder) {
        encoder.encode(out)
        encoder.encode(height)
        encoder.encode(isCoinbase)
    }

    public func encodingSize(_ counter: inout BinaryEncodingSizeCounter) {
        counter.count(out)
        counter.count(Int.self)
        counter.count(Bool.self)
    }
}

extension Optional: BinaryCodable where Wrapped == UnspentOutput {
    public init(from decoder: inout BinaryDecoder) throws {
        let intData = decoder.peek(MemoryLayout<Int>.size)
        if intData == Data([UInt8](repeating: 0xff, count: MemoryLayout<Int>.size)) {
            let decoded: Int = try decoder.decode()
            precondition(decoded == -1)
            self = nil
        } else {
            self = try UnspentOutput(from: &decoder)
        }
    }

    public func encode(to encoder: inout BinaryEncoder) {
        if let self {
            encoder.encode(self)
        } else {
            encoder.encode(-1)
        }
    }

    public func encodingSize(_ counter: inout BinaryEncodingSizeCounter) {
        if let self {
            counter.count(self)
        } else {
            counter.count(Int.self)
        }
    }
}
