import BitcoinBlockchain
import Foundation
import JSONRPC

extension GetBlockchainInfoRPC {
    public func run(blockchain: BlockchainService) async -> Result {
        let chain = await blockchain.params.chain
        let blocks = await blockchain.height
        let headerHeight = await blockchain.headers
        let bestBlockHash = await blockchain.chainTip

        // .locale(US)
        let formatter = FloatingPointFormatStyle<Double>().notation(.scientific).precision(.fractionLength(15))
        // To output `4.656542373906925e-1` instead of 4.6565423739069247e-10
        let difficulty = await blockchain.difficulty

        let time = await blockchain.time
        let medianTime = await blockchain.medianTime
        let verificationProgress = await blockchain.verificationProgress
        let initialBlockDownload = await blockchain.isInitialBlockDownload
        let chainwork = await blockchain.currentChainwork
        let sizeOnDisk = await blockchain.sizeOnDisk

        return .init(
            chain: chain,
            blocks: blocks,
            headers: headerHeight,
            bestBlockHash: bestBlockHash.displayHex,

            // To output `4.656542373906925e-1` instead of 4.6565423739069247e-10
            difficulty: formatter.format(difficulty).lowercased(),
            time: Int(time.timeIntervalSince1970),
            medianTime: Int(medianTime.timeIntervalSince1970),
            verificationProgress: verificationProgress,
            initialBlockDownload: initialBlockDownload,
            chainwork: chainwork.description,
            sizeOnDisk: sizeOnDisk
        )
    }
}
