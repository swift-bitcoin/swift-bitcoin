import BitcoinBlockchain
import Foundation
import JSONRPC

extension ReindexStatusRPC {
    public func run(blockchain: BlockchainService) async -> Result {
        await blockchain.isReindexing
    }
}
