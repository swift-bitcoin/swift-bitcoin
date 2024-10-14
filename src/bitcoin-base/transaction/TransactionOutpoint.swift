import Foundation

/// A reference to a specific ``TransactionOutput`` of a particular ``BitcoinTransaction`` which is stored in a ``TransactionInput``.
public struct TransactionOutpoint: Equatable, Hashable, Sendable {
    
    /// Creates a reference to an output of a previous transaction.
    /// - Parameters:
    ///   - transaction: The identifier for the previous transaction being referenced.
    ///   - output: The index within the previous transaction corresponding to the desired output.
    public init(transaction: TransactionIdentifier, output outputIndex: Int) {
        precondition(transaction.count == BitcoinTransaction.identifierSize)
        self.transactionIdentifier = transaction
        self.outputIndex = outputIndex
    }

    // The identifier for the transaction containing the referenced output.
    public let transactionIdentifier: TransactionIdentifier

    /// The index of an output in the referenced transaction.
    public let outputIndex: Int

    public static let coinbase = Self(
        transaction: .init(count: BitcoinTransaction.identifierSize),
        output: 0xffffffff
    )
}

/// Data extensions.
extension TransactionOutpoint {

    init?(_ data: Data) {
        guard data.count >= Self.size else { return nil }

        var data = data
        let transaction = Data(data.prefix(BitcoinTransaction.identifierSize).reversed())
        data = data.dropFirst(BitcoinTransaction.identifierSize)

        let output = Int(data.withUnsafeBytes { $0.loadUnaligned(as: UInt32.self) })
        self.init(transaction: transaction, output: output)
    }

    var data: Data {
        var ret = Data(count: Self.size)
        let offset = ret.addData(transactionIdentifier.reversed())
        ret.addBytes(UInt32(outputIndex), at: offset)
        return ret
    }

    static let size = BitcoinTransaction.identifierSize + MemoryLayout<UInt32>.size
}

