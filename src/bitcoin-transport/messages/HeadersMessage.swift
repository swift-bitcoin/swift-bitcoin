import Foundation
import BitcoinBlockchain

/// The `headers` message sends block headers to a node which previously requested certain headers with a `getheaders` message. A headers message can be empty.
///
/// Note that the block headers in this packet include a transaction count just like a full block (a `var_int`, so there can be more than 81 bytes per header) as opposed to the block headers that are hashed by miners. This transaction count is always set to 0 however.
///
/// Added inprotocol version `31800`.
///
public struct HeadersMessage: Equatable {

    public init(items: [TxBlock]) {
        self.items = items
    }

    public let items: [TxBlock]

    public static let maxItems = 2000

    public var moreItems: Bool {
        items.count == Self.maxItems
    }
}

extension HeadersMessage {

    public init?(_ data: Data) {
        guard data.count >= 1 else { return nil }
        var data = data

        guard let itemCount = data.varInt, itemCount <= 2_000 else { return nil }
        data = data.dropFirst(itemCount.varIntSize)

        var items = [TxBlock]()
        for _ in 0 ..< itemCount {
            guard let block = try? TxBlock(binaryData: data), block.txs.isEmpty else { return nil }
            items.append(block)
            data = data.dropFirst(block.binarySize)
        }
        self.items = items
    }

    public var data: Data {
        var ret = Data(count: size)
        var offset = ret.addData(Data(varInt: UInt64(items.count)))
        for header in items {
            precondition(header.txs.isEmpty)
            offset = ret.addData(header.binaryData, at: offset)
        }
        return ret
    }

    var size: Int {
        UInt64(items.count).varIntSize + TxBlock.minSize * items.count
    }
}
