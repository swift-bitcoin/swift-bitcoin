import BitcoinBlockchain
import Foundation
import JSONRPC

extension GetMempoolRPC {
    public func run(blockchain: BlockchainService) async -> Result {
        let mempool = await blockchain.mempool
        return .init(
            size: mempool.count,
            txs: mempool.map(\.id.displayHex)
        )
    }
}
