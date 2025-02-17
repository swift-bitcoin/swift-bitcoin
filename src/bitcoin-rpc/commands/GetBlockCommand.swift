import Foundation
import JSONRPC
import BitcoinBase
import BitcoinBlockchain

/// Block information by block ID. Includes a reference to the previous block and a list of transaction IDs.
public struct GetBlockCommand: RPCCommand, Sendable {

    internal struct Output: JSONStringConvertible {
        let id: String
        let previous: String
        let txs: [String]
    }

    public init(_ request: JSONRequest) throws(RPCError) {
        precondition(request.method == Self.method)
        self.request = request

        guard case let .list(objects) = RPCObject(request.params), let first = objects.first, case let .string(blockIDHex) = first else {
            throw .init(.invalidParams("blockID"), description: "BlockID (hex string) is required.")
        }
        guard let blockID = Data(hex: blockIDHex), blockID.count == TxBlock.idLength else {
            throw .init(.invalidParams("blockID"), description: "BlockID hex encoding or length is invalid.")
        }
        self.blockID = blockID
    }

    let request: JSONRequest
    let blockID: BlockID

    public func run(blockchain: BlockchainService) async throws(RPCError) -> JSONResponse {

        guard let block = await blockchain.getBlock(blockID) else {
            throw .init(.invalidParams("blockID"), description: "Block not found.")
        }
        let txs = block.txs.map { $0.id.hex }

        let result = Output(
            id: block.idHex,
            previous: block.previous.hex,
            txs: txs
        )
        return .init(id: request.id, result: JSONObject.string(result.description))
    }

    public static let method = "get-block"
    public static let params = "<block-hash>"
    public static let description = "Returns the specified block's data."
}
