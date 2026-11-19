public import class BitcoinBlockchain.BlockchainService
public import struct JSONRPC.ReindexStopRPC

extension ReindexStopRPC {
    public func run(blockchain: BlockchainService) async {
        await blockchain.stopReindex()
    }
}
