import Foundation

/// A reference to a specific ``TransactionOutput`` of a particular ``BitcoinTransaction`` which is stored in a ``TransactionInput``.
public struct TransactionOutpoint: Equatable, Hashable, Sendable {
    
    /// Creates a reference to an output of a previous transaction.
    /// - Parameters:
    ///   - transaction: The identifier for the previous transaction being referenced.
    ///   - outputIndex: The index within the previous transaction corresponding to the desired output.
    public init(transaction: TransactionID, output outputIndex: Int) {
        precondition(transaction.count == BitcoinTransaction.idLength)
        self.transactionID = transaction
        self.outputIndex = outputIndex
    }

    // The identifier for the transaction containing the referenced output.
    public let transactionID: TransactionID

    /// The index of an output in the referenced transaction.
    public let outputIndex: Int

    public static let coinbase = Self(
        transaction: .init(count: BitcoinTransaction.idLength),
        output: 0xffffffff
    )
}

/// Data extensions.
extension TransactionOutpoint {

    init?(_ data: Data) {
        guard data.count >= Self.size else { return nil }

        var data = data
        let transaction = Data(data.prefix(BitcoinTransaction.idLength).reversed())
        data = data.dropFirst(BitcoinTransaction.idLength)

        let output = Int(data.withUnsafeBytes { $0.loadUnaligned(as: UInt32.self) })
        self.init(transaction: transaction, output: output)
    }

    var data: Data {
        var ret = Data(count: Self.size)
        let offset = ret.addData(transactionID.reversed())
        ret.addBytes(UInt32(outputIndex), at: offset)
        return ret
    }

    static let size = BitcoinTransaction.idLength + MemoryLayout<UInt32>.size
}

