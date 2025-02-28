/// Transaction information including ID, witness ID, inputs and outputs. For each output a raw value is also included in order to facilitate the signing of transactions which require the serialization of previous outputs.
public struct GetTransactionRPC: RPCCommand, Sendable {

    public struct Params: Codable, Sendable {
        public init(transactionID: String) {
            self.transactionID = transactionID
        }

        public let transactionID: String // A transaction identifier.
    }

    public struct Result: Codable, Sendable {
        public init(id: String, witnessID: String, inputs: [GetTransactionRPC.Result.Input], outputs: [GetTransactionRPC.Result.Output]) {
            self.id = id
            self.witnessID = witnessID
            self.inputs = inputs
            self.outputs = outputs
        }

        public struct Input: Codable, Sendable {
            public init(tx: String, output: Int) {
                self.tx = tx
                self.output = output
            }

            public let tx: String
            public let output: Int
        }

        public struct Output: Codable, Sendable {
            public init(raw: String, amount: Int, script: String) {
                self.raw = raw
                self.amount = amount
                self.script = script
            }

            public let raw: String
            public let amount: Int
            public let script: String
        }

        public let id: String
        public let witnessID: String
        public let inputs: [Input]
        public let outputs: [Output]
    }

    public init(_ params: Params) {
        self.params = params
    }

    public let params: Params

    public static let method = "get-transaction"
    public static let params = "<transaction-id>"
    public static let description = "Returns transaction data for the specified transaction ID."
}
