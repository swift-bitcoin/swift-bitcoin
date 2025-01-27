import Foundation
import BitcoinCrypto

/// A reference to a specific ``TxOut`` of a particular ``BitcoinTx`` which is stored in a ``TxIn``.
public struct TxOutpoint: Equatable, Hashable, Sendable {
    
    /// Creates a reference to an output of a previous transaction.
    /// - Parameters:
    ///   - tx: The identifier for the previous transaction being referenced.
    ///   - txOut: The index within the previous transaction corresponding to the desired output.
    public init(tx: TxID, txOut: Int) {
        precondition(tx.count == BitcoinTx.idLength)
        self.txID = tx
        self.txOut = txOut
    }

    // The identifier for the transaction containing the referenced output.
    public let txID: TxID

    /// The index of an output in the referenced transaction.
    public let txOut: Int

    public static let coinbase = Self(
        tx: .init(count: BitcoinTx.idLength),
        txOut: 0xffffffff
    )
}

/// Data extensions.
extension TxOutpoint: BinaryCodable {

    public init(from decoder: inout BinaryDecoder) throws(BinaryDecodingError) {
        let tx = try decoder.decode(BitcoinTx.idLength, byteSwapped: true)
        let txOut = Int(try decoder.decode() as UInt32)
        self.init(tx: tx, txOut: txOut)
    }

    public func encode(to encoder: inout BinaryEncoder) {
        encoder.encode(Data(txID.reversed()))
        encoder.encode(UInt32(txOut))
    }
    
    public func encodingSize(_ counter: inout BinaryEncodingSizeCounter) {
        counter.countSize(BitcoinTx.idLength)
        counter.count(UInt32.self)
    }
}
