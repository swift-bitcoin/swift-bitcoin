/// Mine to a specified address and return the block hashes.
public struct GenerateToAddressRPC: RPCCommand, Sendable {

    public struct Params: Codable, Sendable {
        public init(blocks: Int, address: String, maxTries: Int? = nil) {
            self.blocks = blocks
            self.address = address
            self.maxTries = maxTries
        }

        public let blocks: Int
        public let address: String
        public let maxTries: Int?
    }

    public typealias Result = [String]

    public init(_ params: Params) {
        self.params = params
    }

    public let params: Params

    public static let method = "generate-to-address"
    public static let params = "<blocks> <address> [maxTries]"
    public static let description = "Mine to a specified address and return the block hashes."
}
