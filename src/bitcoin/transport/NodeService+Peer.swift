/// Defines the `Peer` inner struct.
extension NodeService {

    /// Information about a node's remote peer.
    public struct Peer: Sendable {

        /// For incoming peers, the local IP address. For outgoing peers, the remote IP address.
        public let address: IPv6Address

        /// For incoming peers, the local TCP port. For outgoing peers, the remote TCP port.
        public let port: Int

        /// Whether this peer has initiated the connection to us.
        public let incoming: Bool

        /// Our version was acknowledged by the peer.
        var sentVersion = false
        var receivedVersion = false

        /// BIP339
        var sentWTXIDRelayPreference = false

        /// BIP339
        var receivedWTXIDRelayPreference = false

        /// BIP155
        var receivedV2AddressPreference = false

        /// BIP155
        var sentV2AddressPreference = false

        var sentVersionAck = false
        var receivedVersionAck = false

        /// BIP152
        var sentCompactBlocksPreference = false

        /// BIP152
        var highBandwidthCompactBlocks = false

        /// BIP152
        /// We really only support version 2 compact blocks.
        var compactBlocksVersion = Int?.none

        /// BIP152
        var compactBlocksVersionLocked = false

        /// BIP152: Holding pong until our compact block version was sent.
        var pongOnHoldUntilCompactBlocksPreference = PongMessage?.none

        // Information from the version message sent by the peer
        var preferredVersion = ProtocolVersion?.none
        var userAgent = String?.none
        var addressDeclared = IPv6Address?.none
        var portDeclared = Int?.none
        var services = ProtocolServices?.none
        var relay = Bool?.none
        var nonce = UInt64?.none

        /// Difference between the time reported by the peer and our time at the time we receive the version message.
        var timeDiff = 0

        // Status
        public internal(set) var height = 0
        public internal(set) var lastPingNonce = UInt64?.none
        var receivedHeaders = [BlockHeader]?.none

        /// BIP133
        public internal(set) var feeFilterRate = BitcoinAmount?.none // TODO: Honor when relaying transacions (inv) to this peer, #188

        var outgoing: Bool { !incoming }

        /// The connection has been established.
        public var handshakeComplete: Bool {
            sentVersion &&
            receivedVersion &&
            sentWTXIDRelayPreference &&
            receivedWTXIDRelayPreference &&
            sentV2AddressPreference &&
            receivedV2AddressPreference &&
            sentVersionAck &&
            receivedVersionAck
        }
    }
}
