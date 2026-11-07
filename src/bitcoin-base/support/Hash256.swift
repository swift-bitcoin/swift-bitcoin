import BinaryParsing
import BitcoinCrypto
import Crypto
import Foundation

/// A 32-byte hash (Bitcoin's double SHA-256, `HASH256`), stored as `InlineArray<32, UInt8>`:
/// bytes in wire order, alignment 1, no conversion.
///
/// The building block for `TransactionIdentifier` and `BlockHash`. A hash is an identifier, so it is
/// `Hashable` but deliberately not `Comparable`. Proof-of-work is the one place a hash is read as a
/// number; see `BlockHash.meetsTarget(_:)`.
@frozen
public struct Hash256: Hashable, Sendable, CustomDebugStringConvertible {
    public static let byteCount = 32

    public var bytes: InlineArray<32, UInt8>

    @inlinable
    public init(_ bytes: InlineArray<32, UInt8>) {
        self.bytes = bytes
    }

    /// The all-zero hash, Bitcoin Core's null `uint256`: the genesis block's previous block, the
    /// coinbase's outpoint and witness leaf, and the merkle root of no transactions.
    public static let zero = Hash256(InlineArray(repeating: 0))

    /// Whether every byte is zero (Bitcoin Core's `IsNull()`).
    @inlinable
    public var isZero: Bool {
        let words = self.words
        return words.low | words.high == 0
    }

    /// Creates a hash from exactly 32 bytes in wire order, e.g. `data.bytes` or a slice of a
    /// parsed message. Returns `nil` for any other length.
    @inlinable
    public init?(bytes: RawSpan) {
        guard bytes.byteCount == Self.byteCount else { return nil }
        self.bytes = bytes.load(fromByteOffset: 0, as: InlineArray<32, UInt8>.self)
    }

    /// Creates a hash from exactly 32 bytes in wire order, e.g. `array.span`. Returns `nil` for
    /// any other length.
    @inlinable
    public init?(bytes: Span<UInt8>) {
        self.init(bytes: bytes.bytes)
    }

    /// Wraps a CryptoKit digest as is. To compute Bitcoin's double SHA-256, use `init(hashing:)`.
    @inlinable
    public init(_ digest: SHA256.Digest) {
        // The package's one unsafe boundary outside Polyfills/. CryptoKit exposes a digest's bytes only through
        // `withUnsafeBytes` (iterating it copies them into a new Array), so read the 32 bytes there.
        bytes = unsafe digest.withUnsafeBytes { raw in
            precondition(raw.count == Self.byteCount)
            return unsafe raw.loadUnaligned(as: InlineArray<32, UInt8>.self)
        }
    }

    /// Bitcoin's `HASH256` of `bytes`: SHA-256 applied twice. Used for txids, block hashes and
    /// merkle nodes. Pass `data.bytes`, or a slice of a parsed message.
    @inlinable
    public init(hashing bytes: RawSpan) {
        var hasher = SHA256()
        hasher.update(bytes: bytes)
        self.init(finishing: hasher)
    }

    /// Bitcoin's `HASH256` of `bytes`, e.g. `array.span`.
    @inlinable
    public init(hashing bytes: Span<UInt8>) {
        self.init(hashing: bytes.bytes)
    }

    /// `HASH256(left || right)`, a merkle node. Both halves are fed to SHA-256 straight from
    /// their inline storage: nothing is concatenated, copied or allocated.
    @inlinable
    package init(hashingPair left: Hash256, _ right: Hash256) {
        var hasher = SHA256()
        hasher.update(bytes: left.bytes.span.bytes)
        hasher.update(bytes: right.bytes.span.bytes)
        self.init(finishing: hasher)
    }

    /// Finishes the first SHA-256 and applies the second.
    @inlinable
    init(finishing hasher: consuming SHA256) {
        let first = Hash256(hasher.finalize())
        self.init(SHA256.hash(bytes: first.bytes.span.bytes))
    }

    /// Compares as two unaligned `UInt128` words, which measured as fast as a struct of two
    /// `UInt128`s (~0.26 ns). Byte loops were slower: an early-exit loop took ~25 ns, and an
    /// XOR/OR reduction vectorized in a tight loop but not inside `Set`'s probing code, where
    /// insert and lookup ran ~3x slower.
    @inlinable
    public static func == (lhs: Self, rhs: Self) -> Bool {
        let l = lhs.words
        let r = rhs.words
        return ((l.low ^ r.low) | (l.high ^ r.high)) == 0
    }

    /// Feeds only the first 8 bytes (in wire order) to `hasher`; `==` still compares all 32.
    ///
    /// Txids, wtxids, block hashes and merkle roots are SHA-256 outputs, so any 8 of their bytes
    /// are already uniformly distributed, and hashing fewer bytes makes `Set` and `Dictionary`
    /// operations ~30% faster (lookup 68 → 45 ns, insert 71 → 50 ns; 16 bytes gave 60 and 53).
    /// Only in-memory hashing changes: encoding, storage and the wire format are unaffected.
    ///
    /// It has to be the *first* bytes: a block hash's last bytes in wire order are the leading
    /// zeros proof-of-work requires. And crafted collisions stay impractical: `Hasher` is seeded
    /// randomly per process, and making many txids share a 64-bit prefix costs ~2⁶⁴ work each.
    ///
    /// Values that aren't hash outputs should hash all their bytes; see `Target.hash(into:)`.
    @inlinable
    public func hash(into hasher: inout Hasher) {
        hasher.combine(bytes.span.bytes.load(fromByteOffset: 0, as: UInt64.self))
    }
}

// MARK: - Binary encoding

extension Hash256: ExpressibleByParsing {
    /// Consumes 32 bytes in wire order, throwing if fewer remain.
    ///
    /// One bounds-checked 32-byte load from the input (~1.9 ns); `InlineArray(parsing:)` copies
    /// byte by byte (~8.8 ns).
    @inlinable
    public init(parsing input: inout ParserSpan) throws(ParsingError) {
        let slice = try input.extract(byteCount: Self.byteCount)
        self.init(slice.bytes.load(fromByteOffset: 0, as: InlineArray<32, UInt8>.self))
    }

    /// Appends the 32 bytes in wire order. Traps if `output` has fewer than 32 bytes free.
    @inlinable
    public func encode(into output: inout OutputRawSpan) {
        output.append(bytes, as: InlineArray<32, UInt8>.self)
    }

    /// The wire encoding as `Data`, encoded straight into the `Data`'s own storage.
    public var data: Data {
        Data(capacity: Self.byteCount) { encode(into: &$0) }
    }
}

// MARK: - Hex

extension Hash256 {
    /// The bytes as hex in wire order. Bitcoin displays hashes reversed; see `displayHex`.
    public var hexString: String {
        wireBytes.hex
    }
}

// MARK: - Display hex

extension Hash256 {
    /// Spells out the display order, since a bare hash has no single obvious hex form:
    /// `Hash256(displayHex: "000000000019d6…")`.
    public var debugDescription: String {
        "Hash256(displayHex: \"\(displayHex)\")"
    }
}

extension Hash256 {
    /// The hash as Bitcoin displays txids and block hashes: 64 lowercase hex digits with the
    /// bytes reversed, e.g. `000000000019d6689c08…` for the genesis block.
    /// `hexString` gives the bytes in wire order instead.
    public var displayHex: String {
        Array(wireBytes.reversed()).hex
    }

    /// Parses a hash as Bitcoin displays it (see `displayHex`). Requires exactly 64 hex digits;
    /// a `0x` prefix is accepted.
    public init?(displayHex: String) {
        guard let displayOrder = hexBytes(displayHex, byteCount: Self.byteCount, zeroExtend: false) else {
            return nil
        }
        self.init(displayOrder: displayOrder)
    }
}

// MARK: - 256-bit little-endian view

extension Hash256 {
    /// The bytes read as a 256-bit little-endian integer, the reading proof-of-work uses.
    @inlinable
    package var words: (low: UInt128, high: UInt128) {
        let raw = bytes.span.bytes
        return (
            raw.load(fromByteOffset: 0, as: UInt128.self, .littleEndian),
            raw.load(fromByteOffset: 16, as: UInt128.self, .littleEndian)
        )
    }

    @usableFromInline
    init(low: UInt128, high: UInt128) {
        var bytes = InlineArray<32, UInt8>(repeating: 0)
        var span = bytes.mutableSpan
        var raw = span.mutableBytes
        raw.storeBytes(of: low, toByteOffset: 0, as: UInt128.self, .littleEndian)
        raw.storeBytes(of: high, toByteOffset: 16, as: UInt128.self, .littleEndian)
        self.init(bytes)
    }

    /// Whether `lhs` is less than `rhs` as 256-bit little-endian integers.
    @inlinable
    package static func numericallyPrecedes(_ lhs: Self, _ rhs: Self) -> Bool {
        let l = lhs.words
        let r = rhs.words
        return (l.high, l.low) < (r.high, r.low)
    }
}

// MARK: - Hex helpers
// Every hex conversion in the package goes through `Base16Encoder` and `Base16Decoder` (via
// `.hex` and `Data(hex:)`); these add the package's rules: an optional `0x` prefix, fixed or
// maximum widths, and display byte order.

extension Hash256 {
    /// The 32 bytes in wire order, as an array.
    package var wireBytes: [UInt8] { [UInt8](bytes.span.bytes) }

    /// A hash from its 32 bytes in display order: most significant first, the reverse of wire order.
    init(displayOrder bytes: [UInt8]) {
        precondition(bytes.count == Self.byteCount)
        self.init(InlineArray { bytes[Self.byteCount - 1 - $0] })
    }
}

/// Decodes `text` into exactly `byteCount` bytes, most significant first.
///
/// An optional `0x` or `0X` prefix is removed. With `zeroExtend`, fewer digits are accepted and
/// padded with zeros on the left (also making an odd digit count valid); otherwise exactly
/// `2 * byteCount` digits are required. `nil` for too many digits or any non-hex character.
func hexBytes(_ text: String, byteCount: Int, zeroExtend: Bool) -> [UInt8]? {
    let digits = text.hasPrefix("0x") || text.hasPrefix("0X") ? String(text.dropFirst(2)) : text
    let width = 2 * byteCount
    guard zeroExtend ? digits.count <= width : digits.count == width,
        let decoded = Data(hex: String(repeating: "0", count: width - digits.count) + digits)
    else { return nil }
    return [UInt8](decoded)
}
