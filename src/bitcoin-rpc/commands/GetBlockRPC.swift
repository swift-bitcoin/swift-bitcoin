import Foundation
import JSONRPC
import BitcoinCrypto
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
            height: info.height,
            version: block.version,
            versionHex: BinaryEncoder.encode(Int32(block.version)).reversed().hex, // verion as hex string
            merkleRoot: block.merkleRoot.hex,
            time: Int(block.time.timeIntervalSince1970),
            medianTime: Int(info.medianTime.timeIntervalSince1970),
            nonce: block.nonce,
            bits: BinaryEncoder.encode(UInt32(block.target)).reversed().hex, // block.target as hex
            difficulty: info.difficulty, // block.difficulty as double
            chainwork: info.chainwork.reversed().hex,
            transactionCount: txs.count,
            previous: block.previous.hex,
            nextBlock: info.next?.hex,
            strippedsize: block.binarySize(encoding: .nonWitness),
            size: block.binarySize,
            weight: block.weight,
            txs: txs
        )
    }
}
