import Foundation
import BinaryParsing
import BitcoinCrypto

fileprivate let hashLength = SHA256.Digest.byteCount // 32 bytes

/// Return a `headers` packet containing the headers of blocks starting right after the last known hash in the block locator object, up to `hash_stop` or 2000 blocks, whichever comes first. To receive the next block headers, one needs to issue `getheaders` again with a new block locator object. Keep in mind that some clients may provide headers of blocks which are invalid if the block locator object contains a hash on the invalid branch.
public struct GetHeadersMessage: Equatable {

    public init(protocolVersion: ProtocolVersion, locatorHashes: [Data], stopHash: Data? = nil) {
        self.protocolVersion = protocolVersion
        self.locatorHashes = locatorHashes
        self.stopHash = stopHash ?? .init(count: hashLength)
    }

    /// The protocol version number; the same as sent in the `version` message.
    let protocolVersion: ProtocolVersion

    /// block locator objects; newest back to genesis block (dense to start, but then sparse)
    public let locatorHashes: [Data]

    /// The header hash of the last header hash being requested; set to all zeroes to request an `headers` message with all subsequent header hashes (a maximum of 2000 will be sent as a reply to this message; if you need more than 2000, you will need to send another `getheaders` message with a higher-height header hash as the first entry in block header hash field).
    public let stopHash: Data
}

extension GetHeadersMessage: BinaryCodable {

    public enum ParseError: Error {
        /// Maximum hashes is 2000.
        case tooManyHashes
    }

    public init(parsing input: inout ParserSpan, format: Never?) throws {
        protocolVersion = try ProtocolVersion(parsing: &input)

        // number of block locator hash entries
        let hashCount = try VarInt(parsing: &input).value
        guard hashCount <= 2_000 else {
            throw ParsingError(userError: ParseError.tooManyHashes)
        }

        var locatorHashes = [Data]()
        for _ in 0 ..< hashCount {
            let hash = try Data([UInt8](parsing: &input, byteCount: hashLength))
            locatorHashes.append(hash)
        }
        self.locatorHashes = locatorHashes

        stopHash = try Data([UInt8](parsing: &input, byteCount: hashLength))
    }

    public func countBytes(into counter: inout BinarySizeCounter, format: Never?) {
        protocolVersion.countBytes(into: &counter)
        counter.count(VarInt(locatorHashes.count))
        counter.countSize(hashLength * locatorHashes.count)
        counter.countSize(hashLength)
    }

    public func encode(into out: inout OutputRawSpan, format: Never?) throws {
        try protocolVersion.encode(into: &out)
        try VarInt(locatorHashes.count).encode(into: &out)
        for hash in locatorHashes {
            out.append(contentsOf: hash)
        }
        out.append(contentsOf: stopHash)
    }
}
