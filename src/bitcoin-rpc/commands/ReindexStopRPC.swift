import BitcoinBlockchain
import Foundation
import JSONRPC

extension ReindexStopRPC {
    public func run(blockchain: BlockchainService) async {
        await blockchain.stopReindex()
    }
}
