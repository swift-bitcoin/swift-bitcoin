/// If verbosity is 0, returns a string that is serialized, hex-encoded data for block 'hash'.
/// If verbosity is 1, returns an Object with information about block <hash>.
public struct GetBlockRPC: RPCCommand, Sendable {

    public struct Params: Codable, Sendable {
        public init(blockID: String) {
            self.blockID = blockID
        }

        public let blockID: String // A block identifier.
    }

    public struct Result: Codable, Sendable {

        public init(id: String, confirmations: Int, height: Int, version: Int, versionHex: String, merkleRoot: String, time: Int, medianTime: Int, nonce: Int, bits: String, difficulty: Double, chainwork: String, transactionCount: Int, previous: String, nextBlock: String?, strippedsize: Int, size: Int, weight: Int, txs: [String]) {
            self.id = id
            self.confirmations = confirmations
            self.height = height
            self.version = version
            self.versionHex = versionHex
            self.merkleRoot = merkleRoot
            self.time = time
            self.medianTime = medianTime
            self.nonce = nonce
            self.bits = bits
            self.difficulty = difficulty
            self.chainwork = chainwork
            self.transactionCount = transactionCount
            self.previous = previous
            self.nextBlock = nextBlock
            self.strippedsize = strippedsize
            self.size = size
            self.weight = weight
            self.txs = txs
        }


        /// Block ID or _hash_ e.g. `1205ad9b86df6d01c2fbdaef1cc08dcbd02ec3b875763c978da44d87f55fedc2`
        public let id: String

        /// How many mined blocks on top of this one or `chain.totalBlocks - block.height`. Always 1 or higher.
        public let confirmations: Int

        /// The height of this block (0-based index).
        public let height: Int

        public let version: Int // "version": 536870912,
        public let versionHex: String // "versionHex": "20000000",
        public let merkleRoot: String // "merkleroot": "cda84ffb2707461958ad15d50387a167d31c0fd77205496b0761230e460c4ccc",
        public let time: Int // "time": 1740763178,
        public let medianTime: Int // "mediantime": 1740763178,
        public let nonce: Int // "nonce": 4,
        public let bits: String // "bits": "207fffff",
        public let difficulty: Double // "difficulty": 4.656542373906925e-10,
        public let chainwork: String  // "chainwork": "0000000000000000000000000000000000000000000000000000000000000004",

        public let transactionCount: Int // "nTx": 1,
        public let previous: String // "previousblockhash": "0f9188f13cb7b2c71f2a335e3a4fc328bf5beb436012afca590b1a11466e2206",
        public let nextBlock: String? // "nextblockhash": "3dc83cd173be15191c8f1bdbf5ac00a28a8c53f5ac40a912a4c9612378a1f258",

        /// The size not counting transaction witness data.
        public let strippedsize: Int

        /// The size counting transaction witness data.
        public let size: Int

        /// The size not counting transaction witness data.
        public let weight: Int
        public let txs: [String]
    }

    public init(_ params: Params) {
        self.params = params
    }

    public let params: Params

    public static let method = "get-block"
    public static let params = "<block-id>"
    public static let description = "Returns information about the specified block."
}
