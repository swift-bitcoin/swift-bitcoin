import Foundation
import NIOCore
import BitcoinTransport
import Logging
import ServiceLifecycle

actor AutoConnectService: Service {

    init(addresses: [(String, Int)], services: ServiceGroup, eventLoopGroup: EventLoopGroup, node: NodeService, logger: Logger) {
        self.addresses = addresses
        self.services = services
        self.eventLoopGroup = eventLoopGroup
        self.node = node
        self.logger = logger
    }

    let services: ServiceGroup
    let eventLoopGroup: EventLoopGroup
    let node: NodeService
    let logger: Logger

    private var addresses: [(String, Int)] // Address / port
    private var connections = 0
    static let maxConnections = 3

    func run() async throws {
        let connectionUpdates = await node.subscribeToConnections()
        let disconnectionUpdates = await node.subscribeToDisconnections()
        await withDiscardingTaskGroup { g in
            g.addTask {
                await self.connectNext()
            }
            g.addTask {
                for await _ in connectionUpdates.cancelOnGracefulShutdown() {
                    await self.connectNext()
                }
            }
            g.addTask {
                for await _ in disconnectionUpdates.cancelOnGracefulShutdown() {
                    await self.disconnection()
                }
            }
        }
    }

    private func disconnection() async {
        connections -= 1
        await connectNext()
    }

    private func connectNext() async {
        guard connections < Self.maxConnections else {

            return
        }
        guard let (host, port) = addresses.popLast() else {
            return
        }
        connections += 1

        let service = await P2PClient(eventLoopGroup: eventLoopGroup, node: node, logger: logger, host: host, port: port)
        let config = ServiceGroupConfiguration.ServiceConfiguration(
            service: service,
            successTerminationBehavior: .ignore,
            // TODO: Maybe do not shut down when we timeout on an outgoing peer? Or maybe handle any errors inside the client service.
            failureTerminationBehavior: .gracefullyShutdownGroup
        )
        await services.addServiceUnlessShutdown(config)
    }
}
