import Foundation
import JSONRPC
import BitcoinBase
import BitcoinBlockchain

/// Summary of current mempool information including a list of transaction IDs.
public struct GetMempoolCommand: RPCCommand, Sendable {

    struct Output: JSONStringConvertible {
        let size: Int
        let txs: [String]
    }

    public init(_ request: JSONRequest) {
        precondition(request.method == Self.method)
        self.request = request
    }

    let request: JSONRequest

    public func run(blockchain: BlockchainService) async -> JSONResponse {
        let mempool = await blockchain.mempool
        let result = Output(
            size: mempool.count,
            txs: mempool.map(\.id.hex)
        )
        return .init(id: request.id, result: JSONObject.string(result.description))
    }

    public static let method = "get-mempool"
    public static let params = ""
    public static let description: String = "Returns a list of transactions that are in the node's mempool."
}
