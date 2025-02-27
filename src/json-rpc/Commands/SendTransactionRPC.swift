/// Submits a new (raw) transaction to the mempool. The transaction needs to be both valid and signed for it to be accepted.
public struct SendTransactionRPC: RPCCommand, Sendable {

    public struct Params: Codable, Sendable {

        public init(transactionData: String) {
            self.transactionData = transactionData
        }

        public let transactionData: String
    }

    public struct Result: Codable, Sendable {

        public init(mempoolSize: Int) {
            self.mempoolSize = mempoolSize
        }

        public let mempoolSize: Int
    }

    public init(_ params: Params) {
        self.params = params
    }

    public let params: Params

    public static let method = "send-transaction"
    public static let params = "<raw-transaction>"
    public static let description = "Submits the specified transaction to the node."
}
