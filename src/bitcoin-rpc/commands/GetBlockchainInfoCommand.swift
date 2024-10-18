import Foundation
import JSONRPC
import BitcoinBase
import BitcoinBlockchain

public struct GetBlockchainInfoCommand: Sendable {

    internal struct Output: Sendable, CustomStringConvertible, Codable {
        public var description: String {
            let encoder = JSONEncoder()
            encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
            let value = try! encoder.encode(self)
            return String(data: value, encoding: .utf8)!
        }

        public let headers: Int
        public let blocks: Int
        public let hashes: [String]
    }

    public init(bitcoinService: BitcoinService) {
        self.bitcoinService = bitcoinService
    }

    let bitcoinService: BitcoinService

    public func run(_ request: JSONRequest) async -> JSONResponse {

        precondition(request.method == Self.method)

        let headers = await bitcoinService.headers
        let blocks = await bitcoinService.transactions.count
        let result = Output(
            headers: headers.count,
            blocks: blocks,
            hashes: headers.map { $0.idHex }
        )
        return .init(id: request.id, result: JSONObject.string(result.description))
    }

    public static let method = "get-blockchain-info"
}
