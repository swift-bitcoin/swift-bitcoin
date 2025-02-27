import Foundation
import JSONRPC
import BitcoinBase
import BitcoinBlockchain

extension GetBlockRPC {

    public func run(blockchain: BlockchainService) async throws(JSONRPCResponse.Error) -> Result {

        guard let blockID = Data(hex: params.blockID), blockID.count == TxBlock.idLength else {
            throw .init(.invalidParams, "Invalid block hash.")
        }
        guard let block = await blockchain.getBlock(blockID) else {
            throw .init(.invalidParams, "Block not found.")
        }
        guard let info = await blockchain.getBlockInfo(blockID) else {
            throw .init(.internalError, "Failed to get blockchain information for block.")
        }

        let txs = block.txs.map { $0.id.hex }
        return .init(
            id: block.idHex,
            confirmations: info.confirmations,
            size: block.binarySize,
            strippedsize: block.binarySize(encoding: .nonWitness),
            weight: block.weight,
            height: info.height,
            previous: block.previous.hex,
            txs: txs
        )
    }
}
