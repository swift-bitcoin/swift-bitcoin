import BitcoinTransport
import ServiceLifecycle
import Logging

extension NodeService: Service {
    public func run() async throws {
        await withGracefulShutdownHandler {
            await start()
        } onGracefulShutdown: { [logger] in
            logger.info("Node service shutting down gracefully…")
            Task {
                await self.stop()
                logger.info("Node service has shut down.")
            }
        }
    }
}
