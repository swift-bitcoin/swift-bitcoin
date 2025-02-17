import Foundation
import JSONRPC
import BitcoinCrypto
import BitcoinBlockchain

/// Generates blocks with the coinbase output spending to the provided public key.
public struct GenerateToPubkeyCommand: RPCCommand, Sendable {

    public init(_ request: JSONRequest) throws(RPCError) {
        precondition(request.method == Self.method)

        guard case let .list(objects) = RPCObject(request.params), let first = objects.first, case let .string(pubkeyHex) = first else {
            throw .init(.invalidParams("pubkey"), description: "Pubkey (hex string) is required.")
        }
        guard let pubkeyData = Data(hex: pubkeyHex), let pubkey = PubKey(compressed: pubkeyData) else {
            throw .init(.invalidParams("pubkey"), description: "Pubkey hex encoding or content invalid.")
        }
        self.request = request
        self.pubkey = pubkey
    }

    let request: JSONRequest
    let pubkey: PubKey

    /// Request must contain single public key ( hex string) parameter.
    public func run(blockchain: BlockchainService) async -> JSONResponse {

        let newBlock = await blockchain.generateTo(pubkey /*, blockTime: Date(timeIntervalSince1970: 1739295700) */)
        let result = newBlock.idHex

        return .init(id: request.id, result: JSONObject.string(result))
    }

    public static let method = "generate-to"
    public static let params = "<pubkey>"
    public static let description = "Generates a block to the specified public key."
}
