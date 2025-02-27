/// Block hash by height.
public struct GetBlockHashRPC: RPCCommand, Sendable {

    public struct Params: Codable, Sendable {

        public init(height: Int) {
            self.height = height
        }

        public let height: Int
    }

    public struct Result: Codable, Sendable {

        public init(hash: String) {
            self.hash = hash
        }

        public let hash: String
    }

    public init(_ params: Params) {
        self.params = params
    }

    public let params: Params

    public static let method = "get-block-hash"
    public static let params = "<height>"
    public static let description = "Returns hash of block in best-block-chain at height provided."
}
