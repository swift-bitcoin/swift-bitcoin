import Foundation
import BitcoinBase

public struct NodeParams : Sendable {

    public init(network: NodeNetwork = .regtest, version: ProtocolVersion = .latest, services: ProtocolServices = .all, maxInTransitBlocks: Int = 16, feeFilterRate: Amount = 1, highBandwidthCompactBlocks: Bool = false, keepAliveFrequency: Int? = 60, pongTolerance: Int = 15) {
        self.network = network
        self.version = version
        self.services = services
        self.maxInTransitBlocks = maxInTransitBlocks
        self.feeFilterRate = feeFilterRate
        self.highBandwidthCompactBlocks = highBandwidthCompactBlocks
        self.keepAliveFrequency = keepAliveFrequency
        self.pongTolerance = pongTolerance
    }

    /// The type of bitcoin network this node is part of.
    public let network: NodeNetwork

    public let version: ProtocolVersion
    public let services: ProtocolServices

    public let maxInTransitBlocks: Int
    public let feeFilterRate: Amount
    public let highBandwidthCompactBlocks: Bool

    /// Optional frequency to send keep-alive ping to peers in seconds. Default value is `60`. Nil value means regular pings will not be sent.
    public let keepAliveFrequency: Int?

    /// How long (in seconds) will the node wait for the pong response from peer which has been sent a ping.  Default value is `15`.
    public let pongTolerance: Int
}
