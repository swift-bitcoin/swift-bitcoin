import Bitcoin
import ServiceLifecycle

extension NodeService: Service {
    public func run() async throws {
        let blocks = await bitcoinService.subscribeToBlocks()
        self.blocks = blocks
        await withGracefulShutdownHandler {
            for await block in blocks.cancelOnGracefulShutdown() {
                // If we have peers, send them the block
                print("New block (might send to peer):\n\t\(block.hash.hex)]")
            }
            await self.bitcoinService.unsubscribe(blocks)
        } onGracefulShutdown: {
            print("BitcoinNode Service shutting down gracefully")
        }
    }
}
