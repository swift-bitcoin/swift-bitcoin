import BitcoinBase

public import class BitcoinBlockchain.BlockchainService
public import struct JSONRPC.GetMempoolRPC

extension GetMempoolRPC {
    public func run(blockchain: BlockchainService) async -> Result {
        let mempool = await blockchain.mempool
        return .init(
            size: mempool.count,
            txs: mempool.map(\.id.displayHex)
        )
    }
}
