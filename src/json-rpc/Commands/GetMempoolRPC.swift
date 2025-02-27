/// Summary of current mempool information including a list of transaction IDs.
public struct GetMempoolRPC: RPCCommand, Sendable {

    public typealias Params = Never

    public struct Result: Codable, Sendable {
        public init(size: Int, txs: [String]) {
            self.size = size
            self.txs = txs
        }

        let size: Int
        let txs: [String]
    }

    public init() {}

    public static let method = "get-mempool"
    public static let params = ""
    public static let description: String = "Summary of current mempool information including a list of transaction IDs."
}
