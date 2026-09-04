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
        guard let block = await blockchain.header(for: blockID) else {
            throw .init(.invalidParams, "Block not found.")
        }
        guard let info = await blockchain.blockInfo(for: blockID) else {
            throw .init(.internalError, "Failed to get blockchain information for block.")
        }

        let blockVersionData = Data(capacity: MemoryLayout<Int32>.size) { out in
            out.append(Int32(block.version), as: Int32.self, .bigEndian)
        }

        let blockTargetData = Data(capacity: MemoryLayout<UInt32>.size) { out in
            out.append(UInt32(block.target), as: UInt32.self, .bigEndian)
        }

        return .init(
            id: block.idHex,
            confirmations: info.confirmations,
            status: info.status.description,
            height: info.height,
            version: block.version,
            versionHex: blockVersionData.hex, // verion as hex string
            merkleRoot: block.merkleRoot.reversed().hex,
            time: Int(block.time.timeIntervalSince1970),
            medianTime: Int(info.medianTime.timeIntervalSince1970),
            nonce: block.nonce,
            bits: blockTargetData.hex, // block.target as hex
            difficulty: info.difficulty, // block.difficulty as double
            chainwork: info.chainwork.reversed().hex,
            previous: block.previous.reversed().hex,
            nextBlock: info.next?.reversed().hex
        )
    }
}
