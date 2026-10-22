import Foundation
import BinaryParsing
import BitcoinCrypto
import BitcoinBase
import BitcoinBlockchain

/// The `headers` message sends block headers to a node which previously requested certain headers with a `getheaders` message. A headers message can be empty.
///
/// Note that the block headers in this packet include a transaction count just like a full block (a `var_int`, so there can be more than 81 bytes per header) as opposed to the block headers that are hashed by miners. This transaction count is always set to 0 however.
///
/// Added inprotocol version `31800`.
///
public struct HeadersMessage: Equatable {

    public init(items: [Block]) {
        self.items = items
    }

    public let items: [Block]

    public static let maxItems = 2000

    public var moreItems: Bool {
        items.count == Self.maxItems
    }
}

extension HeadersMessage: BinaryCodable {

    public enum ParseError: Error {
        /// Maximum headers is 2000.
        case tooManyHeaders

        /// Headers are encoded as blocks without transactions.
        case transactionInHeader
    }

    public init(parsing input: inout ParserSpan, format: Never?) throws {
        let itemCount = try VarInt(parsing: &input).value
        guard itemCount <= 2_000 else {
            throw ParsingError(userError: ParseError.tooManyHeaders)
        }
        var items = [Block]()
        for _ in 0 ..< itemCount {
            let block = try Block(parsing: &input)

            guard block.txs.isEmpty else {
                throw ParsingError(userError: ParseError.tooManyHeaders)
            }
            items.append(block)
        }
        self.items = items
    }

    public func countBytes(into counter: inout BinarySizeCounter, format: Never?) {
        counter.count(VarInt(items.count))
        counter.countSize(Block.minSize * items.count)
    }

    public func encode(into out: inout OutputRawSpan, format: Never?) throws {
        try VarInt(items.count).encode(into: &out)
        for header in items {
            precondition(header.txs.isEmpty)
            try header.encode(into: &out)
        }
    }
}

