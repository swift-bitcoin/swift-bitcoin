import Foundation

/// The object type is currently defined as one of the following possibilities: `ERROR`, `MSG_TX`, `MSG_BLOCK`, `MSG_FILTERED_BLOCK`, `MSG_CMPCT_BLOCK`, `MSG_WITNESS_TX`, `MSG_WITNESS_BLOCK`, `MSG_FILTERED_WITNESS_BLOCK`.
public enum InventoryType: Int {

    /// `ERROR`: Any data of with this number may be ignored.
    case error = 0

    /// `MSG_TX`: Hash is related to a transaction.
    case transaction = 1

    /// `MSG_BLOCK`: Hash is related to a data block.
    case block = 2

    /// `MSG_FILTERED_BLOCK`: Hash of a block header; identical to `MSG_BLOCK`. Only to be used in `getdata` message. Indicates the reply should be a `merkleblock` message rather than a `block` message; this only works if a bloom filter has been set. See BIP37 for more info.
    case filteredBlock = 3

    /// `MSG_CMPCT_BLOCK`: Hash of a block header; identical to `MSG_BLOCK`. Only to be used in `getdata` message. Indicates the reply should be a `cmpctblock` message. See BIP152 for more info..
    case compactBlock = 4

    /// `MSG_WITNESS_TX`: Hash of a transaction with witness data. See BIP144 for more info.
    case witnessTransaction = 0x40000001

    /// `MSG_WITNESS_BLOCK`: Hash of a block with witness data. See BIP144 for more info.
    case witnessBlock = 0x40000002

    /// `MSG_FILTERED_WITNESS_BLOCK`: Hash of a block with witness data. Only to be used in `getdata` message. Indicates the reply should be a `merkleblock` message rather than a `block` message; this only works if a bloom filter has been set. See BIP144 for more info.
    case filteredWitnessBlock = 0x40000003
}

extension InventoryType {

    init?(_ data: Data) {
        guard data.count >= Self.size else { return nil }
        let value = data.withUnsafeBytes {
            $0.loadUnaligned(as: UInt32.self)
        }
        self.init(rawValue: Int(value))
    }

    var data: Data {
        Data(value: UInt32(rawValue))
    }

    static var size: Int { MemoryLayout<UInt32>.size }
}
