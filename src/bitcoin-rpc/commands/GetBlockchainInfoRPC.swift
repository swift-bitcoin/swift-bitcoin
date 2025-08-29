import Foundation
import JSONRPC
import BitcoinBlockchain

extension GetBlockchainInfoRPC {

    public func run(blockchain: BlockchainService) async -> Result {
        let chain = await blockchain.params.chain
        let blocks = await blockchain.height
        let headerHeight = await blockchain.headers
        let bestBlockHash = await blockchain.chainTip

        let formatter = FloatingPointFormatStyle<Double>().notation(.scientific).precision(.fractionLength(15)) // .locale(US)
        // To output `4.656542373906925e-1` instead of 4.6565423739069247e-10
        let difficulty = await blockchain.difficulty

        let time = await blockchain.time
        let medianTime = await blockchain.medianTime
        let verificationProgress = await blockchain.verificationProgress
        let initialBlockDownload = await blockchain.initialBlockDownload
        let chainwork = await blockchain.chainwork
        let sizeOnDisk = await blockchain.sizeOnDisk

        return .init(
            chain: chain,
            blocks: blocks,
            headers: headerHeight,
            bestBlockHash: bestBlockHash!.reversed().hex,
            difficulty: formatter.format(difficulty).lowercased(), // To output `4.656542373906925e-1` instead of 4.6565423739069247e-10
            time: Int(time.timeIntervalSince1970),
            medianTime: Int(medianTime.timeIntervalSince1970),
            verificationProgress: verificationProgress,
            initialBlockDownload: initialBlockDownload,
            chainwork: chainwork.hex,
            sizeOnDisk: sizeOnDisk
        )
    }
}
