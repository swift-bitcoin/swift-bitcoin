import Foundation
import JSONRPC
import BitcoinBlockchain

extension ReindexRPC {

    public func run(blockchain: BlockchainService) async {
        await blockchain.startReindex()
    }
}
