import Foundation
import JSONRPC
import BitcoinTransport

extension GetPeerInfoRPC {

    public func run(node: NodeService) async -> Result {

        let peers = await node.state.peers

        return peers.keys.map { id in
            let peer = peers[id]!
            return ResultItem(id: id, connectionType: peer.incoming ? .incoming : .outgoing)
        }
    }
}
