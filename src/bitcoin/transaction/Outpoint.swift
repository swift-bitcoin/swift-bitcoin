import Foundation

/// A reference to a particular ``Output`` of a particular ``Transaction``.
public struct Outpoint: Equatable {

    init(transaction: Data, output: Int) {
        precondition(transaction.count == Transaction.idSize)
        self.transaction = transaction
        self.output = output
    }

    init?(_ data: Data) {
        guard data.count >= Self.size else {
            return nil
        }
        var offset = data.startIndex
        let transaction = Data(data[offset ..< offset + Transaction.idSize].reversed())
        offset += Transaction.idSize
        let outputData = data[offset ..< offset + MemoryLayout<UInt32>.size]
        let output = Int(outputData.withUnsafeBytes {
            $0.loadUnaligned(as: UInt32.self)
        })
        self.init(transaction: transaction, output: output)
    }

    // The identifier for the transaction containing the referenced output.
    public var transaction: Data

    /// The index of an output in the referenced transaction.
    public var output: Int

    var data: Data {
        var ret = Data()
        ret += transaction.reversed()
        ret += withUnsafeBytes(of: UInt32(output)) { Data($0) }
        return ret
    }

    public static let coinbase = Self(
        transaction: .init(count: Transaction.idSize),
        output: 0xffffffff
    )

    static let size = Transaction.idSize + MemoryLayout<UInt32>.size
}
