import Foundation
import JSONRPC
import BitcoinTransport

/// Disconnects a peer.
public struct DisconnectPeerCommand: RPCCommand, Sendable {

    public init(_ request: JSONRequest) throws(RPCError) {
        precondition(request.method == Self.method)

        guard case let .list(objects) = RPCObject(request.params), let first = objects.first, case let .string(peerIDString) = first else {
            throw .init(.invalidParams("peer-id"), description: "Parameter `peer-id` (`UUID`) is required.")
        }
        guard let peerID = UUID(uuidString: peerIDString) else {
            throw .init(.invalidParams("peer-id"), description: "Parameter `peer-id` (`UUID`) could not be parsed.")
        }
        self.peerID = peerID
    }

    let peerID: PeerID

    public func run(node: NodeService) async {
        await node.removePeer(peerID)
    }

    public static let method = "disconnect-peer"
    public static let params = "<peer-id>"
    public static let description = "Disconnects peer from node."
}
