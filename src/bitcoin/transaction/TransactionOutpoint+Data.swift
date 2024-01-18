import Foundation

extension TransactionOutpoint {

    init?(_ data: Data) {
        guard data.count >= Self.size else { return nil }

        var data = data
        let transaction = Data(data[..<data.startIndex.advanced(by: BitcoinTransaction.identifierSize)].reversed())
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
