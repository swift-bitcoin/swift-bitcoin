import Foundation
import JSONRPC
import BitcoinTransport

extension DisconnectPeerRPC {
    public func run(node: NodeService) async -> Bool {
        await node.removePeer(params.peerID)
        return true
    }
}
