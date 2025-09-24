import Foundation
import BitcoinBase

public struct NodeState: Sendable {

    public init(feeFilterRate: Amount = 1, peers: [UUID : PeerState] = [UUID : PeerState]()) {
        self.feeFilterRate = feeFilterRate
        self.peers = peers
    }

    /// BIP133: Our current fee filter rate for transactions relayed to us by state.state.peers. Default: 1 satoshi per virtual byte (sat/vbyte).
    public var feeFilterRate: Amount // TODO: Allow to be changed via RPC command, #189

    /// Peer information.
    public internal(set) var peers = [UUID : PeerState]()

    @usableFromInline static let initial = Self()
}
