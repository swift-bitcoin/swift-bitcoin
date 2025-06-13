import BitcoinBase
import BitcoinBlockchain
import Foundation

/// Information about a node's remote peer.
public struct PeerState: Sendable {

    /// For incoming peers, the local IP address. For outgoing peers, the remote IP address.
    public let address: IPv6Address

    /// For incoming peers, the local TCP port. For outgoing peers, the remote TCP port.
    public let port: Int

    /// Whether this peer has initiated the connection to us.
    public let incoming: Bool

    var outbox = [Message]()

    /// Whether our node has already sent the version message to this peer.
    var versionSent = false

    // Information from the version message sent by the peer
    var version = VersionMessage?.none

    /// BIP339
    var witnessRelayPreferenceSent = false

    /// BIP339
    var witnessRelayPreferenceReceived = false

    /// BIP155
    var v2AddressPreferenceReceived = false

    /// BIP155
    var v2AddressPreferenceSent = false

    var versionAckSent = false
    var versionAckReceived = false

    /// BIP152
    var compactBlocksPreferenceSent = false

    /// BIP152
    var highBandwidthCompactBlocks = false

    /// BIP152
    /// We really only support version 2 compact blocks.
    var compactBlocksVersion = Int?.none

    /// BIP152
    var compactBlocksVersionLocked = false

    /// BIP152: Holding pong until our compact block version was sent.
    var pongOnHoldUntilCompactBlocksPreference = PongMessage?.none

    /// Difference between the time reported by the peer and our time at the time we receive the version message.
    var timeDiff = 0

    var inTransitBlocks = 0

    // MARK: - Status

    public internal(set) var height = 0
    public internal(set) var lastPingNonce = UInt64?.none
    public private(set) var knownBlocks = [Block.ID]()
    public private(set) var knownTxs = [Transaction.ID]()

    /// BIP152
    var pendingBlockTxs = [Transaction?]?.none

    var nextPingTask: Task<(), Never>?
    var checkPongTask: Task<(), Never>?

    /// BIP133
    public internal(set) var feeFilterRate = Amount?.none // TODO: Honor when relaying transacions (inv) to this peer, #188

    var outgoing: Bool { !incoming }

    /// The connection has been established.
    public var handshakeComplete: Bool {
        version != .none &&
        witnessRelayPreferenceReceived &&
        v2AddressPreferenceReceived &&
        versionAckReceived
    }

    mutating func registerKnownBlocks(_ ids: [Block.ID]) {
        knownBlocks = knownBlocks + ids
        let count = knownBlocks.count
        if count > maxKnownBlocks {
            knownBlocks.removeFirst(count - maxKnownBlocks)
        }
    }

    mutating func registerKnownTxs(_ ids: [Transaction.ID]) {
        knownTxs = knownTxs + ids
        let count = knownTxs.count
        if count > maxKnownTxs {
            knownTxs.removeFirst(count - maxKnownTxs)
        }
    }
}

private let maxKnownBlocks = 3
private let maxKnownTxs = 10
