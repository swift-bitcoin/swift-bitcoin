import Foundation

/// `getdata` is used in response to `inv`, to retrieve the content of a specific object, and is usually sent after receiving an inv packet, after filtering known elements. It can be used to retrieve transactions, but only if they are in the memory pool or relay set - arbitrary access to transactions in the chain is not allowed to avoid having clients start to depend on nodes having full transaction indexes (which modern nodes do not).
/// Payload (maximum 50,000 entries, which is just over 1.8 megabytes).
public struct GetDataMessage: Equatable {

    public init(items: [InventoryItem]) {
        self.items = items
    }

    public let items: [InventoryItem]
}

extension GetDataMessage {

    public init?(_ data: Data) {
        guard data.count >= 1 else { return nil }
        var data = data

        guard let itemCount = data.varInt, itemCount <= 50_000 else { return nil }
        data = data.dropFirst(itemCount.varIntSize)

        var items = [InventoryItem]()
        for _ in 0 ..< itemCount {
            guard let item = InventoryItem(data) else { return nil }
            items.append(item)
            data = data.dropFirst(InventoryItem.size)
        }
        self.items = items
    }

    var data: Data {
        var ret = Data(count: size)
        var offset = ret.addData(Data(varInt: UInt64(items.count)))
        for item in items {
            offset = ret.addData(item.data, at: offset)
        }
        return ret
    }

    var size: Int {
        UInt64(items.count).varIntSize + InventoryItem.size * items.count
    }
}
