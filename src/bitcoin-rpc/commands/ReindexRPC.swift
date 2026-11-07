import BitcoinBlockchain
import Foundation
import JSONRPC

extension ReindexRPC {
    public func run(blockchain: BlockchainService) async {
        await blockchain.startReindex()
    }
}
