import Foundation
import JSONRPC
import BitcoinBase
import BitcoinBlockchain

/// Block information by block ID. Includes a reference to the previous block and a list of transaction IDs.
public struct GetBlockCommand: Sendable {

    internal struct Output: Sendable, CustomStringConvertible, Codable {

        public let id: String
        public let previous: String
        public let transactions: [String]

        public var description: String {
            let encoder = JSONEncoder()
            encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
            let value = try! encoder.encode(self)
            return String(data: value, encoding: .utf8)!
        }
    }

    public init(bitcoinService: BitcoinService) {
        self.bitcoinService = bitcoinService
    }

    let bitcoinService: BitcoinService

    public func run(_ request: JSONRequest) async throws -> JSONResponse {

        precondition(request.method == Self.method)

        guard case let .list(objects) = RPCObject(request.params), let first = objects.first, case let .string(blockIDHex) = first else {
            throw RPCError(.invalidParams("blockID"), description: "BlockID (hex string) is required.")
        }
        guard let blockID = Data(hex: blockIDHex), blockID.count == BlockHeader.idLength else {
            throw RPCError(.invalidParams("blockID"), description: "BlockID hex encoding or length is invalid.")
        }

        guard let block = await bitcoinService.getBlock(blockID) else {
            throw RPCError(.invalidParams("blockID"), description: "Block not found.")
        }
        let transactions = block.transactions.map { $0.id.hex }

        let result = Output(
            id: block.header.idHex,
            previous: block.header.previous.hex,
            transactions: transactions
        )
        return .init(id: request.id, result: JSONObject.string(result.description))
    }

    public static let method = "get-block"
}
