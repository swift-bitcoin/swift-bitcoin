import Foundation
import BinaryParsing
import BitcoinCrypto
import BitcoinBase

/// Inventory vectors are used for notifying other nodes about objects they have or data which is being requested.
public struct InventoryItem: Equatable {

    public init(type: InventoryType, hash: Hash256) {
        self.type = type
        self.hash = hash
    }

    /// Identifies the object type linked to this inventory.
    public let type: InventoryType

    /// Hash of the object.
    public let hash: Hash256
}

extension InventoryItem: BinaryCodable {

    public init(parsing input: inout ParserSpan, format: Never?) throws {
        type = try InventoryType(parsing: &input)
        hash = try Hash256(parsing: &input)
    }

    public func countBytes(into counter: inout BinarySizeCounter, format: Never?) {
        counter.count(type)
        counter.countSize(Hash256.byteCount)
    }

    public func encode(into out: inout OutputRawSpan, format: Never?) throws {
        try type.encode(into: &out)
        hash.encode(into: &out)
    }
}
