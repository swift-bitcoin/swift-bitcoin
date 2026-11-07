import BitcoinBlockchain
import Foundation
import JSONRPC

extension GetBlockHashRPC {
    public func run(blockchain: BlockchainService) async throws(JSONRPCResponse.Error) -> Result {
        guard let blockID = await blockchain.blockID(at: params.height) else {
            throw .init(.invalidParams, "Block not found at height \(params.height).")
        }

        let result = blockID.displayHex
        return .init(hash: result)
    }
}
