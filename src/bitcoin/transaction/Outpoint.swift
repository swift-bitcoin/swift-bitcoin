import Foundation

/// A reference to a particular ``Output`` of a particular ``Transaction``.
public struct Outpoint: Equatable {

    public init(transaction: String, output: Int) {
        self.transaction = transaction
        self.output = output
    }

    // The identifier for the transaction containing the referenced output.
    public var transaction: String

    /// The index of an output in the referenced transaction.
    public var output: Int

    var data: Data {
        var ret = Data()
        ret += Data(hex: transaction).reversed()
        ret += withUnsafeBytes(of: UInt32(output)) { Data($0) }
        return ret
    }

    static var size: Int {
        Transaction.idSize + MemoryLayout<UInt32>.size
    }
}
