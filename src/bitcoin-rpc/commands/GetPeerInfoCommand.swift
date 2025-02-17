import Foundation
import JSONRPC
import BitcoinBase
import BitcoinBlockchain
import BitcoinTransport

/// Returns a list of peers along with information about them.
public struct GetPeerInfoCommand: RPCCommand, Sendable {

    struct Output: JSONStringConvertible {

        enum ConnectiontType: Encodable { case outgoing, incoming }

        public let id: String
        public let connectionType: ConnectiontType
    }

    public init(_ request: JSONRequest) {
        precondition(request.method == Self.method)
        self.request = request
    }

    let request: JSONRequest

    public func run(node: NodeService) async -> JSONResponse {

        let peers = await node.state.peers

        let result = peers.keys.map { id in
            let peer = peers[id]!
            return Output(id: id.uuidString, connectionType: peer.incoming ? .incoming : .outgoing)
        }.map(\.description).joined(separator: "\n")
        return .init(id: request.id, result: JSONObject.string(result))
    }

    public static let method = "get-peer-info"
    public static let params = ""
    public static let description = "Returns a list of peers along with information about them."
}
