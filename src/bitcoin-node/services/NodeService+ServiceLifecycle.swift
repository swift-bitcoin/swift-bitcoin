import BitcoinTransport
import ServiceLifecycle
import Logging

private let logger = Logger(label: "swift-bitcoin.node")

extension NodeService: Service {
    public func run() async throws {
        await start()
        guard let blocks else { await stop(); return }

        await withGracefulShutdownHandler {
            for await block in blocks.cancelOnGracefulShutdown() {
                await handleBlock(block)
            }
            await stop()
        } onGracefulShutdown: {
            logger.info("BitcoinNode Service shutting down gracefully")
        }
    }
}
