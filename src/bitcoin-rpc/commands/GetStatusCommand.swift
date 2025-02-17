import Foundation
import JSONRPC
import BitcoinBase
import BitcoinBlockchain

/// Status of the RPC and Peer-to-Peer services.
public struct GetStatusCommand: RPCCommand, Sendable {

    public init(_ request: JSONRequest) {
        precondition(request.method == Self.method)
        self.request = request
    }

    let request: JSONRequest

    public func run(rpcStatus: RPCServiceStatus, p2pStatus: P2PServiceStatus, p2pClientStatus: [P2PClientStatus]) async -> JSONResponse {

        let result = """
        RPC server status:
        \(rpcStatus)

        P2P server status:
        \(p2pStatus)

        P2P clients' status:
        \(p2pClientStatus.map(\.description).joined(separator: "\n\n"))
        """

        return .init(id: request.id, result: JSONObject.string(result.description))
    }

    public static let method = "status"
    public static let params = ""
    public static let description = "Displays status for all of the node's services."
}
