import Foundation
import BitcoinCrypto
import BitcoinBase

/// A reference to an unspent transaction output (aka _UTXO_).
struct UnspentOutput: Equatable, Sendable {

    let out: TransactionOutput
    let height: Int
    let isCoinbase: Bool

    init(_ out: TransactionOutput, height: Int = Self.mempoolHeight, isCoinbase: Bool = false) {
        precondition(height > 0 && height <= Self.mempoolHeight && !(isCoinbase && height == Self.mempoolHeight))
        self.out = out
        self.height = height
        self.isCoinbase = isCoinbase
    }

    var isMempool: Bool {
        height == Self.mempoolHeight
    }
    static let mempoolHeight = 0x7fffffff
}

extension UnspentOutput: BinaryCodable {

    init(from decoder: inout BinaryDecoder) throws {
        out = try decoder.decode()
        height = try decoder.decode()
        isCoinbase = try decoder.decode()
    }
    
    func encode(to encoder: inout BinaryEncoder) {
        encoder.encode(out)
        encoder.encode(height)
        encoder.encode(isCoinbase)
    }
    
    func encodingSize(_ counter: inout BinaryEncodingSizeCounter) {
        counter.count(out)
        counter.count(Int.self)
        counter.count(Bool.self)
    }
}
