import Foundation
import BinaryParsing
import BitcoinCrypto

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
}

extension InventoryItem: BinaryCodable {

    public init(parsing input: inout ParserSpan, format: Never?) throws {
        type = try InventoryType(parsing: &input)
        hash = try Data([UInt8](parsing: &input, byteCount: hashLength))
    }

    public func countBytes(into counter: inout BinarySizeCounter, format: Never?) {
        counter.count(type)
        counter.countSize(hashLength)
    }

    public func encode(into out: inout OutputRawSpan, format: Never?) throws {
        try type.encode(into: &out)
        out.append(contentsOf: hash)
    }
}

fileprivate let hashLength = SHA256.Digest.byteCount // 32 bytes
