import Foundation
import JSONRPC
import BitcoinCrypto
import BitcoinBase
import BitcoinBlockchain

extension GetHeaderRPC {

    public func run(blockchain: BlockchainService) async throws(JSONRPCResponse.Error) -> Result {

        guard let blockIDByteSwapped = Data(hex: params.blockID), blockIDByteSwapped.count == Block.idLength else {
            throw .init(.invalidParams, "Invalid block hash.")
        }
        let blockID = Data(blockIDByteSwapped.reversed())
        guard let block = await blockchain.getHeader(blockID) else {
            throw .init(.invalidParams, "Block not found.")
        }
        guard let info = await blockchain.getBlockInfo(blockID) else {
            throw .init(.internalError, "Failed to get blockchain information for block.")
        }

        return .init(
            id: block.idHex,
            confirmations: info.confirmations,
            status: info.status.description,
            height: info.height,
            version: block.version,
            versionHex: BinaryEncoder.encode(Int32(block.version)).reversed().hex, // verion as hex string
            merkleRoot: block.merkleRoot.reversed().hex,
            time: Int(block.time.timeIntervalSince1970),
            medianTime: Int(info.medianTime.timeIntervalSince1970),
            nonce: block.nonce,
            bits: BinaryEncoder.encode(UInt32(block.target)).reversed().hex, // block.target as hex
            difficulty: info.difficulty, // block.difficulty as double
            chainwork: info.chainwork.reversed().hex,
            previous: block.previous.reversed().hex,
            nextBlock: info.next?.reversed().hex
        )
    }
}
