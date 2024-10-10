import Foundation
import BitcoinCrypto

fileprivate let hashLength = SHA256.Digest.byteCount // 32 bytes

/// Return a `headers` packet containing the headers of blocks starting right after the last known hash in the block locator object, up to `hash_stop` or 2000 blocks, whichever comes first. To receive the next block headers, one needs to issue `getheaders` again with a new block locator object. Keep in mind that some clients may provide headers of blocks which are invalid if the block locator object contains a hash on the invalid branch.
public struct GetHeadersMessage: Equatable {

    public init(protocolVersion: ProtocolVersion, locatorHashes: [Data], stopHash: Data? = .none) {
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

extension GetHeadersMessage {

    public init?(_ data: Data) {
        guard data.count >= 1 else { return nil }
        var data = data

        guard let protocolVersion = ProtocolVersion(data) else { return nil }
        self.protocolVersion = protocolVersion
        data = data.dropFirst(ProtocolVersion.size)

        // number of block locator hash entries
        guard let hashCount = data.varInt, hashCount <= 2_000 else { return nil }
        data = data.dropFirst(hashCount.varIntSize)

        var locatorHashes = [Data]()
        for _ in 0 ..< hashCount {
            guard data.count >= hashLength else { return nil }
            let hash = data.prefix(hashLength)
            locatorHashes.append(hash)
            data = data.dropFirst(hashLength)
        }
        self.locatorHashes = locatorHashes

        guard data.count >= hashLength else { return nil }
        self.stopHash = data.prefix(hashLength)

    }

    var data: Data {
        var ret = Data(count: size)

        var offset = ret.addData(protocolVersion.data)

        offset = ret.addData(Data(varInt: UInt64(locatorHashes.count)), at: offset)
        for hash in locatorHashes {
            offset = ret.addData(hash, at: offset)
        }

        ret.addData(stopHash, at: offset)
        return ret
    }

    var size: Int {
        ProtocolVersion.size + UInt64(locatorHashes.count).varIntSize + hashLength * locatorHashes.count + hashLength
    }
}
