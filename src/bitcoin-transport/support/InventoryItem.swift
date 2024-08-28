import Foundation

/// Inventory vectors are used for notifying other nodes about objects they have or data which is being requested.
public struct InventoryItem: Equatable {

    public init(type: InventoryType, hash: Data) {
        self.type = type
        self.hash = hash
    }

    /// Identifies the object type linked to this inventory.
    public let type: InventoryType

    /// Hash of the object.
    public let hash: Data

    static let size = InventoryType.size + 32
}

extension InventoryItem {

    public init?(_ data: Data) {
        guard data.count >= Self.size else { return nil }
        var data = data

        guard let type = InventoryType(data) else { return nil }
        self.type = type
        data = data.dropFirst(InventoryType.size)

        guard data.count >= 32 else { return nil }
        self.hash = data.prefix(32)
    }

    var data: Data {
        var ret = Data(count: Self.size)
        let offset = ret.addData(type.data)
        ret.addData(hash, at: offset)
        return ret
    }
}
