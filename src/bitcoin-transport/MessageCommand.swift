import Foundation

/// The message command represents the different kinds of message on the peer-to-peer network.
public enum MessageCommand: String, RawRepresentable, Sendable {

    /// Initial message in the handshake sequence.
    /// The payload is a serialized ``ProtocolVersion``.
    case version

    /// Response to ``version``.
    /// This message command does not carry a payload.
    case verack

    /// Sent primarily to confirm that the TCP/IP connection is still valid. An error in transmission is presumed to be a closed connection and the address is removed as a current peer.
    /// The payload is a serialized ``PingMessage``.
    case ping

    /// Sent in response to a ``ping`` message. A pong response is generated using a nonce included in the ping.
    /// The payload is a serialized ``PongMessage``.
    case pong

    /// BIP339
    case wtxidrelay

    /// Legacy / unsupported.
    /// Provides information on known nodes of the network. Non-advertised nodes should be forgotten after typically 3 hours.
    case addr

    /// Legacy / unsupported.
    /// The getaddr message sends a request to a node asking for information about known active peers to help with finding potential nodes in the network. The response to receiving this message is to transmit one or more addr messages with one or more peers from a database of known active peers. The typical presumption is that a node is likely to be active if it has been sending a message within the last three hours.
    /// This message command does not carry a payload.
    case getaddr

    /// Legacy / unsupported.
    /// Return an inv packet containing the list of blocks starting right after the last known hash in the block locator object, up to `hash_stop` or 500 blocks, whichever comes first.
    case getblocks

    /// BIP155
    case sendaddrv2

    /// The payload is a serialized ``AddrV2Message``.
    /// BIP155
    case addrv2

    /// The payload is a serialized ``SendCompactMessage``.
    /// BIP152
    case sendcmpct

    /// The payload is a serialized ``CompactBlockMessage``.
    /// BIP152
    case cmpctblock

    /// Response to ``cmpctblock`` when at least one transaction is missing.
    /// BIP152
    /// The payload is a serialized ``GetBlockTransactionsMessage``.
    case getblocktxn

    /// Response to ``getblocktxn``.
    /// The payload is a serialized ``BlockTransactionsMessage``.
    /// BIP152
    case blocktxn

    /// The payload is a serialized ``GetHeadersMessage``.
    case getheaders

    /// Response to ``getheaders``.
    /// The payload is a serialized ``HeadersMessage``.
    case headers

    /// Indicates that a node prefers to receive new block announcements via a "headers" message rather than an "inv".
    /// BIP130
    case sendheaders

    /// The payload is a serialized ``FeeFilterMessage``.
    /// BIP133
    case feefilter

    /// Allows a node to advertise its knowledge of one or more objects. It can be received unsolicited, or in reply to ``getblocks``.
    /// The payload is a serialized ``InventoryMessage`` (maximum 50,000 entries, which is just over 1.8 megabytes).
    case inv

    /// Used in response to ``inv``, to retrieve the content of a specific object, and is usually sent after receiving an inv packet, after filtering known elements. It can be used to retrieve transactions, but only if they are in the memory pool or relay set - arbitrary access to transactions in the chain is not allowed to avoid having clients start to depend on nodes having full transaction indexes (which modern nodes do not).
    /// The payload is a serialized ``GetDataMessage`` (maximum 50,000 entries, which is just over 1.8 megabytes).
    case getdata

    /// A response to a ``getdata``, sent if any requested data items could not be relayed, for example, because the requested transaction was not in the memory pool or relay set.
    /// This message command does not carry a payload.
    case notfound

    /// A transaction block in reply to ``getdata`` which requests transaction information from a block hash. The payload is a serialized `Block`.
    case block

    /// A Bitcoin transaction in reply to ``getdata``. The payload is a serialized `Transaction`.
    case tx

    case unknown

    static let size = 12 // Data size

    init(tentativeRawValue: String) {
        // Messages received after connection to server: version, wtxidrelay sendaddrv2, verack, sendcmpct, ping, getheaders, feefilter
        self = Self(rawValue: tentativeRawValue) ?? .unknown
    }
}

extension MessageCommand {

    init?(_ data: Data) {
        guard data.count >= Self.size else { return nil }
        let commandDataUntrimmed = data.prefix(Self.size)
        let commandData = commandDataUntrimmed.reversed().trimmingPrefix(while: { $0 == 0x00 }).reversed()
        let commandRawValue = String(decoding: commandData, as: Unicode.ASCII.self)
        self.init(tentativeRawValue: commandRawValue)
    }

    var data: Data {
        var ret = Data(count: Self.size)
        let commandData = rawValue.data(using: .ascii)!
        let offset = ret.addData(commandData)
        let commandPaddingData = Data(repeating: 0, count: Self.size - commandData.count)
        ret.addData(commandPaddingData, at: offset)
        return ret
    }
}
