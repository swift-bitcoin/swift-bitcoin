import Foundation
import JSONRPC
import BitcoinBlockchain

extension GetBlockHashRPC {

    public func run(blockchain: BlockchainService) async throws(JSONRPCResponse.Error) -> Result {

        guard let blockID = await blockchain.getBlockID(at: params.height) else {
            throw .init(.invalidParams, "Block not found at height \(params.height).")
        }

        let result = blockID.hex
        return .init(hash: result)
    }
}
