import Foundation
import JSONRPC
import BitcoinCrypto
import BitcoinBlockchain
import BitcoinWallet

/// Mine to a specified address and return the block hashes.
public struct GenerateToAddressCommand: RPCCommand, Sendable {

    public init(_ request: JSONRequest) throws(RPCError) {
        precondition(request.method == Self.method)
        self.request = request
        guard
            case let .list(params) = RPCObject(request.params),
            params.count >= 2 else {
            throw .init(.invalidParams("blocks,address"), description: "Parameters <blocks> and <address> are required.")
        }
        guard case let .integer(blocks) = params[0], blocks >= 1 else {
            throw .init(.invalidParams("blocks"), description: "Parameter <blocks> must be an integer between 1 and \(Int.max).")

        }
        guard
            case let .string(addressString) = params[1],
            let address = AnyAddress(addressString) else {
            throw .init(.invalidParams("address"), description: "Address is invalid.")
        }
        self.blocks = blocks
        self.address = address
        if params.count >= 3 {
            guard case let .integer(maxTries) = params[2], blocks >= 1 else {
                throw .init(.invalidParams("maxTries"), description: "Parameter <maxTries> must be an integer between 1 and \(Int.max).")

            }
            self.maxTries = maxTries
        } else {
            self.maxTries = Self.defaultMaxTries
        }
    }

    let request: JSONRequest
    let blocks: Int
    let address: AnyAddress
    let maxTries: Int

    /// Request must contain single public key ( hex string) parameter.
    public func run(blockchain: BlockchainService) async throws(RPCError) -> JSONResponse {
        let chain = await blockchain.params.chain
        guard address.isCompatibleWithChain(chain) else {
            throw .init(.invalidParams("address"), description: "Address network incompatible with '\(chain)' chain.")
        }
        let blockIDs = await blockchain.generateToScript(address.script, blocks: blocks, maxTries: maxTries /*, blockTime: Date(timeIntervalSince1970: 1739295700) */)
        let result = JSONObject.list(blockIDs.map { JSONObject.string($0.hex) })

        return .init(id: request.id, result: result)
    }

    public static let defaultMaxTries = BlockchainService.Config.defaultMaxTries

    // RPCCommand
    public static let method = "generate-to-address"
    public static let params = "<blocks> <address> [maxTries]"
    public static let description = "Mine to a specified address and return the block hashes."
}
