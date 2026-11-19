public import class BitcoinBlockchain.BlockchainService
public import struct JSONRPC.ReindexStatusRPC

extension ReindexStatusRPC {
    public func run(blockchain: BlockchainService) async -> Result {
        await blockchain.isReindexing
    }
}
