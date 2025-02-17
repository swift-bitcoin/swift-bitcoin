import Foundation
import JSONRPC
import BitcoinBase
import BitcoinBlockchain

/// Block hash by height.
public struct GetBlockHashCommand: RPCCommand, Sendable {

    public init(_ request: JSONRequest) throws(RPCError) {
        precondition(request.method == Self.method)
        self.request = request
        guard case let .list(objects) = RPCObject(request.params), let first = objects.first, case let .string(heightString) = first else {
            throw .init(.invalidParams("height"), description: "Parameter `height` (`Int`) is required.")
        }
        guard let height = Int(heightString) else {
            throw .init(.invalidParams("height"), description: "Parameter `height` (`Int`) could not be parsed.")
        }
        self.height = height
    }

    let request: JSONRequest
    let height: Int

    public func run(blockchain: BlockchainService) async throws(RPCError) -> JSONResponse {

        guard let blockID = await blockchain.getBlockID(at: height) else {
            throw .init(.invalidParams("height"), description: "Block not found.")
        }

        let result = blockID.hex
        return .init(id: request.id, result: JSONObject.string(result))
    }

    public static let method = "get-block-hash"
    public static let params = "<height>"
    public static let description = "Returns hash of block in best-block-chain at height provided."
}
