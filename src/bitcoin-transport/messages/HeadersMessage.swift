import Foundation
import BitcoinBlockchain

/// The `headers` message sends block headers to a node which previously requested certain headers with a `getheaders` message. A headers message can be empty.
///
/// Note that the block headers in this packet include a transaction count just like a full block (a `var_int`, so there can be more than 81 bytes per header) as opposed to the block headers that are hashed by miners. This transaction count is always set to 0 however.
///
/// Added inprotocol version `31800`.
///
public struct HeadersMessage: Equatable {

    public init(items: [BlockHeader]) {
        self.items = items
    }

    public let items: [BlockHeader]
}

extension HeadersMessage {

    public init?(_ data: Data) {
        guard data.count >= 1 else { return nil }
        var data = data

        guard let itemCount = data.varInt, itemCount <= 2_000 else { return nil }
        data = data.dropFirst(itemCount.varIntSize)

        var items = [BlockHeader]()
        for _ in 0 ..< itemCount {
            guard let block = TransactionBlock(data), block.transactions.isEmpty else { return nil }
            items.append(block.header)
            data = data.dropFirst(BlockHeader.size)
        }
        self.items = items
    }

    var data: Data {
        var ret = Data(count: size)
        var offset = ret.addData(Data(varInt: UInt64(items.count)))
        for header in items {
            offset = ret.addData(TransactionBlock(header: header).data, at: offset)
        }
        return ret
    }

    var size: Int {
        UInt64(items.count).varIntSize + (BlockHeader.size + 1) * items.count
    }
}
