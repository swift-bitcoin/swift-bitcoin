/// Get information about the block header.
public struct GetHeaderRPC: RPCCommand, Sendable {

    public struct Params: Codable, Sendable {
        public init(blockID: String) {
            self.blockID = blockID
        }

        public let blockID: String // A block identifier.
    }

    public struct Result: Codable, Sendable {

        public init(id: String, confirmations: Int, status: String, height: Int, version: Int, versionHex: String, merkleRoot: String, time: Int, medianTime: Int, nonce: Int, bits: String, difficulty: Double, chainwork: String, previous: String, nextBlock: String?) {
            self.id = id
            self.confirmations = confirmations
            self.status = status
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
            self.previous = previous
            self.nextBlock = nextBlock
        }


        /// Block ID or _hash_ e.g. `1205ad9b86df6d01c2fbdaef1cc08dcbd02ec3b875763c978da44d87f55fedc2`
        public let id: String

        /// How many mined blocks on top of this one or `chain.totalBlocks - block.height`. Always 1 or higher.
        public let confirmations: Int

        public let status: String

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

        public let previous: String // "previousblockhash": "0f9188f13cb7b2c71f2a335e3a4fc328bf5beb436012afca590b1a11466e2206",
        public let nextBlock: String? // "nextblockhash": "3dc83cd173be15191c8f1bdbf5ac00a28a8c53f5ac40a912a4c9612378a1f258",
    }

    public init(_ params: Params) {
        self.params = params
    }

    public let params: Params

    public static let method = "get-header"
    public static let params = "<block-id>"
    public static let description = "Returns information about the specified block header."
}
