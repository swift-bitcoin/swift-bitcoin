public import class BitcoinTransport.NodeService
public import struct JSONRPC.DisconnectPeerRPC

extension DisconnectPeerRPC {
    public func run(node: NodeService) async -> Bool {
        await node.removePeer(params.peerID)
    }
}
