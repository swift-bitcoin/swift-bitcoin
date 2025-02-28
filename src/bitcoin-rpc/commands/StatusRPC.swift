import Foundation
import JSONRPC

extension StatusRPC {

    public func run(rpcStatus: Result.RPCService, p2pStatus: Result.P2PService, p2pClientStatus: [Result.P2PClient]) async -> Result {
        .init(
            rpcStatus: rpcStatus,
            p2pStatus: p2pStatus,
            p2pClientStatus: p2pClientStatus
        )
    }
}
