import Foundation
import BitcoinCrypto
import BitcoinBase

/// A reference to an unspent transaction output (aka _UTXO_).
struct UnspentOut: Equatable, Sendable {

    let txOut: TxOut
    let height: Int
    let isCoinbase: Bool

    init(_ txOut: TxOut, height: Int = Self.mempoolHeight, isCoinbase: Bool = false) {
        precondition(height > 0 && height <= Self.mempoolHeight && !(isCoinbase && height == Self.mempoolHeight))
        self.txOut = txOut
        self.height = height
        self.isCoinbase = isCoinbase
    }

    var isMempool: Bool {
        height == Self.mempoolHeight
    }
    static let mempoolHeight = 0x7fffffff
}

extension UnspentOut: BinaryCodable {

    init(from decoder: inout BinaryDecoder) throws(BinaryDecodingError) {
        txOut = try decoder.decode()
        height = try decoder.decode()
        isCoinbase = try decoder.decode()
    }
    
    func encode(to encoder: inout BinaryEncoder) {
        encoder.encode(txOut)
        encoder.encode(height)
        encoder.encode(isCoinbase)
    }
    
    func encodingSize(_ counter: inout BinaryEncodingSizeCounter) {
        counter.count(txOut)
        counter.count(Int.self)
        counter.count(Bool.self)
    }
}
