import Foundation
import JSONRPC
import BitcoinBlockchain

extension ReindexStopRPC {

    public func run(blockchain: BlockchainService) async {
        await blockchain.stopReindex()
    }
}
