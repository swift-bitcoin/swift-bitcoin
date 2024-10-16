import Foundation
import BitcoinBase
import BitcoinBlockchain

public struct GetBlockCommand: Sendable {

    internal struct Output: Sendable, CustomStringConvertible, Codable {

        public let identifier: String
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

        guard case let .list(objects) = RPCObject(request.params), let first = objects.first, case let .string(blockIdentifierHex) = first else {
            throw RPCError(.invalidParams("blockIdentifier"), description: "BlockIdentifier (hex string) is required.")
        }
        guard let blockIdentifier = Data(hex: blockIdentifierHex), blockIdentifier.count == BlockHeader.identifierLength else {
            throw RPCError(.invalidParams("blockIdentifier"), description: "BlockIdentifier hex encoding or length is invalid.")
        }

        guard let block = await bitcoinService.getBlock(blockIdentifier) else {
            throw RPCError(.invalidParams("blockIdentifier"), description: "Block not found.")
        }
        let transactions = block.transactions.map { $0.identifier.hex }

        let result = Output(
            identifier: block.header.identifierHex,
            previous: block.header.previous.hex,
            transactions: transactions
        )
        return .init(id: request.id, result: JSONObject.string(result.description))
    }

    public static let method = "get-block"
}
