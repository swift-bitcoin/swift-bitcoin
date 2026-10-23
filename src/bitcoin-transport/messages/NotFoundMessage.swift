import Foundation
import BinaryParsing
import BitcoinCrypto

/// `notfound` is a response to a `getdata`, sent if any requested data items could not be relayed, for example, because the requested transaction was not in the memory pool or relay set.
/// Payload (maximum 50,000 entries, which is just over 1.8 megabytes).
public struct NotFoundMessage: Equatable {

    public init(items: [InventoryItem]) {
        self.items = items
    }

    public let items: [InventoryItem]
}

extension NotFoundMessage: BinaryCodable {

    public enum ParseError: Error {
        /// Maximum inventory items is 50,000.
        case tooManyItems
    }

    public init(parsing input: inout ParserSpan, format: Never?) throws {
        let itemCount = try VarInt(parsing: &input).value
        guard itemCount <= 50_000 else {
            throw ParsingError(userError: ParseError.tooManyItems)
        }
        var items = [InventoryItem]()
        for _ in 0 ..< itemCount {
            let item = try InventoryItem(parsing: &input)
            items.append(item)
        }
        self.items = items
    }

    public func countBytes(into counter: inout BinarySizeCounter, format: Never?) {
        counter.count(VarInt(items.count))
        // TODO: Figure out a protocol for types with a fixed binary encoding size with propagation so we can do optimizations like `counter.countSize(InventoryItem.fixedSize * items.count)`.
        for item in items {
            counter.count(item)
        }
    }

    public func encode(into out: inout OutputRawSpan, format: Never?) throws {
        try VarInt(items.count).encode(into: &out)
        for item in items {
            try item.encode(into: &out)
        }
    }
}
