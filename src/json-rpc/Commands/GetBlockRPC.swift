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

        public init(id: String, confirmations: Int, size: Int, strippedsize: Int, weight: Int, height: Int, previous: String, txs: [String]) {
            self.id = id
            self.confirmations = confirmations
            self.size = size
            self.strippedsize = strippedsize
            self.weight = weight
            self.height = height
            self.previous = previous
            self.txs = txs
        }

        public let id: String
        public let confirmations: Int
        public let size: Int
        public let strippedsize: Int
        public let weight: Int
        public let height: Int
        public let previous: String
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
