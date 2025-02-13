import Foundation
import JSONRPC
import BitcoinBase
import BitcoinBlockchain

/// Summary of current blockchain information such as total number of headers, blocks and a list of block IDs (hashes).
public struct GetBlockchainInfoCommand: Sendable {

    public struct Output: JSONStringConvertible {

        /// Current network name (main, test, testnet4, signet, regtest).
        public let chain: String

        /// The height of the most-work fully-validated chain. The genesis block has height 0.
        public let blocks: Int

        /// The current number of headers we have validated.
        public let headers: Int

        /// The hash of the currently best block.
        public let bestBlockHash: String

        /// The current difficulty. Contains a double formatted as a scientific notation string.
        public let difficulty: String // Should be a double but the Swift JSON encoder formats scientific notation a little different than Bitcoin Core's (one less digit)

        /// The block time expressed in UNIX epoch time
        public let time: Int

        /// The median block time expressed in UNIX epoch time
        public let medianTime: Int

        /// estimate of verification progress [0..1]
        public let verificationProgress: Double

        /// (debug information) estimate of whether this node is in Initial Block Download mode
        public let initialBlockDownload: Bool

        /// total amount of work in active chain, in hexadecimal
        public let chainwork: String

        /// the estimated size of the block and undo files on disk
        public let sizeOnDisk: Int

        public let hashes: [String]
    }

    public init(blockchain: BlockchainService) {
        self.blockchain = blockchain
    }

    let blockchain: BlockchainService

    public func run() async -> Output {
        let chain = await blockchain.params.chain
        let blocks = await blockchain.validatedHeight
        let headerIDs = await blockchain.headerIDs
        let bestBlockHash = await blockchain.chainTip

        let formatter = FloatingPointFormatStyle<Double>().notation(.scientific).precision(.fractionLength(15))
        // To output `4.656542373906925e-1` instead of 4.6565423739069247e-10
        let difficulty = await blockchain.tipDifficulty

        let time = await blockchain.tipTime
        let medianTime = await blockchain.medianTime
        let verificationProgress = await blockchain.verificationProgress
        let initialBlockDownload = await blockchain.initialBlockDownload
        let chainwork = await blockchain.chainwork
        let sizeOnDisk = await blockchain.sizeOnDisk

        let result = Output(
            chain: chain,
            blocks: blocks,
            headers: headerIDs.count - 1,
            bestBlockHash: bestBlockHash!.hex,
            difficulty: formatter.format(difficulty).lowercased(), // To output `4.656542373906925e-1` instead of 4.6565423739069247e-10
            time: Int(time.timeIntervalSince1970),
            medianTime: Int(medianTime.timeIntervalSince1970),
            verificationProgress: verificationProgress,
            initialBlockDownload: initialBlockDownload,
            chainwork: chainwork.hex,
            sizeOnDisk: sizeOnDisk,
            hashes: headerIDs.map(\.hex)
        )
        return result
    }

    public func run(_ request: JSONRequest) async -> JSONResponse {
        precondition(request.method == Self.method)

        let result = await run()
        return .init(id: request.id, result: JSONObject.string(result.description))
    }

    public static let method = "get-blockchain-info"
}
