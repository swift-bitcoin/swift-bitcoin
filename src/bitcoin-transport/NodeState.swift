import Foundation
import BitcoinBase

public struct NodeState: Sendable {

    public init(feeFilterRate: Amount = 1, ibdComplete: Bool = false, peers: [UUID : PeerState] = [UUID : PeerState]()) {
        self.feeFilterRate = feeFilterRate
        self.peers = peers
        self.ibdComplete = ibdComplete
    }

    /// BIP133: Our current fee filter rate for transactions relayed to us by state.state.peers. Default: 1 satoshi per virtual byte (sat/vbyte).
    public var feeFilterRate: Amount // TODO: Allow to be changed via RPC command, #189

    /// Initial Block Download (IBD) has completed. Default: false. Block data will start being requested as compact block instead of witness block.
    public var ibdComplete : Bool

    /// Peer information.
    public internal(set) var peers = [UUID : PeerState]()

    @usableFromInline static let initial = Self()
}
