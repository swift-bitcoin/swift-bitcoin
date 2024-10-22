import Foundation
import JSONRPC
import BitcoinBase
import BitcoinBlockchain

/// Summary of current mempool information including a list of transaction IDs.
public struct GetMempoolCommand: Sendable {

    internal struct Output: Sendable, CustomStringConvertible, Codable {
        public var description: String {
            let encoder = JSONEncoder()
            encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
            let value = try! encoder.encode(self)
            return String(data: value, encoding: .utf8)!
        }

        public let size: Int
        public let transactions: [String]
    }

    public init(bitcoinService: BitcoinService) {
        self.bitcoinService = bitcoinService
    }

    let bitcoinService: BitcoinService

    public func run(_ request: JSONRequest) async -> JSONResponse {

        precondition(request.method == Self.method)

        let mempool = await bitcoinService.mempool
        let result = Output(
            size: mempool.count,
            transactions: mempool.map(\.id.hex)
        )
        return .init(id: request.id, result: JSONObject.string(result.description))
    }

    public static let method = "get-mempool"
}
