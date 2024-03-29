import Foundation

/// `notfound` is a response to a `getdata`, sent if any requested data items could not be relayed, for example, because the requested transaction was not in the memory pool or relay set.
/// Payload (maximum 50,000 entries, which is just over 1.8 megabytes).
public struct NotFoundMessage: Equatable {

    public init(items: [InventoryItem]) {
        self.items = items
    }

    public let items: [InventoryItem]
}

extension NotFoundMessage {

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
