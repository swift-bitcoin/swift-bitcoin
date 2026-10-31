import BinaryParsing

/// A type whose identity is a `Hash256`: same 32 bytes, same layout, its own type so a
/// transaction identifier can't be passed where a block hash is expected.
public protocol Hash256Identifier: Hashable, Sendable, CustomStringConvertible, ExpressibleByParsing {
    var hash: Hash256 { get }
    init(_ hash: Hash256)
}

extension Hash256Identifier {
    /// The all-zero identifier, e.g. `BlockHash.zero` as the genesis block's previous block, or
    /// `TransactionIdentifier.zero` in the coinbase's outpoint. See `Hash256.zero`.
    @inlinable
    public static var zero: Self { Self(.zero) }

    /// Whether every byte is zero (Bitcoin Core's `IsNull()`).
    @inlinable
    public var isZero: Bool { hash.isZero }

    /// As Bitcoin displays it: 64 hex digits, bytes reversed. See `Hash256.displayHex`.
    public var displayHex: String { hash.displayHex }

    /// Parses the displayed form (see `Hash256.init(displayHex:)`).
    public init?(displayHex: String) {
        guard let hash = Hash256(displayHex: displayHex) else { return nil }
        self.init(hash)
    }

    public var description: String { displayHex }

    /// Consumes 32 bytes in wire order, throwing if fewer remain.
    @inlinable
    public init(parsing input: inout ParserSpan) throws(ParsingError) {
        self.init(try Hash256(parsing: &input))
    }

    /// Appends the 32 bytes in wire order. Traps if `output` has fewer than 32 bytes free.
    @inlinable
    public func encode(into output: inout OutputRawSpan) {
        hash.encode(into: &output)
    }
}
