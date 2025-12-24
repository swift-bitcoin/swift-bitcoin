import ArgumentParser
import Foundation
import JSONRPC

struct SendCommand: AsyncParsableCommand {

    static let configuration = CommandConfiguration(
        abstract: "Sends an RPC command to a running Swift Bitcoin node."
    )

    @OptionGroup var parent: Node

    @Argument(help: "The JSON-RPC method name.")
    var method: String

    @Argument(help: "The JSON-RPC parameter structure.")
    var params: String?

    mutating func run() async throws {
        if ([
            HelpRPC.self,
            StatusRPC.self,
            StopRPC.self,
            StartP2PRPC.self,
            StopP2PRPC.self,
            ConnectRPC.self,
            DisconnectPeerRPC.self,
            GetBlockHashRPC.self,
            GetBlockRPC.self,
            GetHeaderRPC.self,
            GenerateToAddressRPC.self,
            GetBlockchainInfoRPC.self,
            GetChainTipsRPC.self,
            GetMempoolRPC.self,
            GetPeerInfoRPC.self,
            GetTransactionRPC.self,
            SendTransactionRPC.self,
            ReindexRPC.self,
            ReindexStatusRPC.self,
            ReindexStopRPC.self
        ] as [any RPCCommand.Type]).map({ $0.method}).contains(method) {
            // try StartP2P.parseAsRoot(params).run()
            throw ValidationError("Use bcutil node \(method) command instead.")
        }
        guard let params = (params ?? "null").data(using: .utf8) else {
            throw ValidationError("Invalid params.")
        }
        let decoder = JSONDecoder()
        decoder.userInfo[.method] = method
        let requestParams: JSONRPCRequest.Params
        do {
            requestParams = try decoder.decode(JSONRPCRequest.Params.self, from: params)
        } catch {
            throw ValidationError("Method \(method) not found, or invalid parameter structure.")
        }
        try await sendRPC(host: parent.host, port: parent.resolvedPort, request: JSONRPCRequest(requestParams))
    }
}
