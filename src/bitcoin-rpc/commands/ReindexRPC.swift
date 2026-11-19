public import class BitcoinBlockchain.BlockchainService
public import struct JSONRPC.ReindexRPC

extension ReindexRPC {
    public func run(blockchain: BlockchainService) async {
        await blockchain.startReindex()
    }
}
