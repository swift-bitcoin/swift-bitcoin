import Foundation
import JSONRPC
import BitcoinBlockchain

extension ReindexStatusRPC {

    public func run(blockchain: BlockchainService) async -> Result {
        await blockchain.isReindexing
    }
}
