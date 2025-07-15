/// Summary of current blockchain information such as total number of headers, blocks and a list of block IDs (hashes).
public struct GetBlockchainInfoRPC: RPCCommand, Sendable {

    public typealias Params = Never

    public struct Result: Codable, Sendable {

        public init(chain: String, blocks: Int, headers: Int, bestBlockHash: String, difficulty: String, time: Int, medianTime: Int, verificationProgress: Double, initialBlockDownload: Bool, chainwork: String, sizeOnDisk: Int/*, hashes: [String]*/) {
            self.chain = chain
            self.blocks = blocks
            self.headers = headers
            self.bestBlockHash = bestBlockHash
            self.difficulty = difficulty
            self.time = time
            self.medianTime = medianTime
            self.verificationProgress = verificationProgress
            self.initialBlockDownload = initialBlockDownload
            self.chainwork = chainwork
            self.sizeOnDisk = sizeOnDisk
            //self.hashes = hashes
        }

        /// Current network name (main, test, testnet4,, regtest, signet).
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

        //public let hashes: [String]
    }

    public init() {}

    public static let method = "get-blockchain-info"
    public static let params = ""
    public static let description: String = "Returns an object containing various state info regarding blockchain processing."
}
