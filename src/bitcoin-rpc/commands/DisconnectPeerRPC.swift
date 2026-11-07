import BitcoinTransport
import Foundation
import JSONRPC

extension DisconnectPeerRPC {
    public func run(node: NodeService) async -> Bool {
        await node.removePeer(params.peerID)
    }
}
