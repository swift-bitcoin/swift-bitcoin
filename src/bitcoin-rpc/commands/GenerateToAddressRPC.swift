import Foundation
import JSONRPC
import BitcoinCrypto
import BitcoinBlockchain
import BitcoinWallet

extension GenerateToAddressRPC {

    /// Request must contain single public key ( hex string) parameter.
    public func run(blockchain: BlockchainService) async throws(JSONRPCResponse.Error) -> [String] {

        guard params.blocks >= 1 else {
            throw .init(.invalidParams, "Parameter <blocks> must be an integer between 1 and \(Int.max).")
        }
        guard let address = AnyAddress(params.address) else {
            throw .init(.invalidParams, "Address '\(params.address)' is invalid.")
        }

        if let maxTries = params.maxTries {
            guard maxTries > 0 else {
                throw .init(.invalidParams, "Parameter <maxTries> must be an integer between 1 and \(Int.max).")
            }
        }

        let chain = await blockchain.params.chain
        guard address.isCompatibleWithChain(chain) else {
            throw .init(.invalidParams, "Address network incompatible with '\(chain)' chain.")
        }
        let blockIDs = await blockchain.generateToScript(address.script, blocks: params.blocks, maxTries: params.maxTries ?? BlockchainService.Config.defaultMaxTries /*, blockTime: Date(timeIntervalSince1970: 1739295700) */)

        return blockIDs.map(\.hex)
    }
}
