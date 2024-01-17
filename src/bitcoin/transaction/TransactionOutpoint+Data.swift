import Foundation

extension TransactionOutpoint {

    init?(_ data: Data) {
        guard data.count >= Self.size else {
            return nil
        }
        var offset = data.startIndex
        let transaction = Data(data[offset ..< offset + BitcoinTransaction.identifierSize].reversed())
        offset += BitcoinTransaction.identifierSize
        let outputData = data[offset ..< offset + MemoryLayout<UInt32>.size]
        let output = Int(outputData.withUnsafeBytes {
            $0.loadUnaligned(as: UInt32.self)
        })
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
