import Foundation
import NIOPosix
import BitcoinTransport
import JSONRPC
import AsyncAlgorithms
import ServiceLifecycle
import NIOCore
import NIOExtras
import Logging
private let logger = Logger(label: "swift-bitcoin.p2p")

actor P2PService: Service {

    init(eventLoopGroup: EventLoopGroup, node: NodeService) {
        self.eventLoopGroup = eventLoopGroup
        self.node = node
    }

    let eventLoopGroup: EventLoopGroup
    let node: NodeService

    // Status
    private(set) var running = false
    private(set) var listening = false
    private(set) var host = String?.none
    private(set) var port = Int?.none
    private(set) var overallConnections = 0
    private(set) var sessionConnections = 0
    private(set) var activeConnections = 0

    private let listenRequests = AsyncChannel<()>() // We'll send () to this channel whenever we want the service to bootstrap itself

    private var serverChannel: NIOAsyncChannel<NIOAsyncChannel<NetworkMessage, NetworkMessage>, Never>?
    private var peerIDs = [UUID]()

    var status: StatusRPC.Result.P2PService {
        .init(running: running, listening: listening, host: host, port: port, overallConnections: overallConnections, sessionConnections: sessionConnections, activeConnections: activeConnections)
    }

    func run() async throws {
        // Update status
        running = true

        try await withGracefulShutdownHandler {
            for await _ in listenRequests.cancelOnGracefulShutdown() {
                try await startListening()
            }
        } onGracefulShutdown: {
            logger.info("P2P server shutting down gracefully…")
        }
    }

    func start(host: String, port: Int) async {
        guard serverChannel == nil else { return }
        self.host = host
        self.port = port
        await node.setAddress(host, port)
        await listenRequests.send(()) // Signal to start listening
    }

    func stopListening() async throws {
        try await serverChannel?.channel.close()
        serverChannel = nil
        listening = false
        host = nil
        port = nil
        sessionConnections = 0
        activeConnections = 0
        await node.resetAddress()
    }

    private func serviceUp() {
        listening = true
    }

    private func connectionMade() {
        overallConnections += 1
        sessionConnections += 1
        activeConnections += 1
    }

    private func clientDisconnected() {
        if listening {
            activeConnections -= 1
        }
    }

    private func startListening() async throws {
        guard let host, let port else {
            logger.error("Host and port not set.")
            return
        }

        // Bootstraping server channel.
        let bootstrap = ServerBootstrap(group: eventLoopGroup)
        let serverChannel = try await bootstrap.bind(
            host: host,
            port: port
        ) { connection in
            // This closure is called for every inbound connection.
            connection.eventLoop.makeCompletedFuture {
                try connection.pipeline.syncOperations.addHandlers([
                    ByteToMessageHandler(MessageCoder()),
                    MessageToByteHandler(MessageCoder()),
                    DebugInboundEventsHandler(),
                    DebugOutboundEventsHandler()
                ])
                return try NIOAsyncChannel<NetworkMessage, NetworkMessage>(wrappingChannelSynchronously: connection)
            }
        }
        self.serverChannel = serverChannel

        // Accept connections
        try await withThrowingDiscardingTaskGroup { @Sendable group in

            try await serverChannel.executeThenClose { serverChannelInbound in
                logger.info("P2P server accepting incoming connections on \(host):\(port)…")

                await serviceUp()

                for try await connectionChannel in serverChannelInbound.cancelOnGracefulShutdown() {

                    guard let remoteAddress = connectionChannel.channel.remoteAddress,
                          let remoteHost = remoteAddress.ipAddress,
                          let remotePort = remoteAddress.port else {
                        logger.error("Could not obtain remote address.")
                        continue
                    }
                    logger.info("P2P server received incoming connection from peer @ \(remoteAddress).")

                    await connectionMade()

                    group.addTask {
                        do {
                            try await connectionChannel.executeThenClose { inbound, outbound in

                                let peerID = await self.node.addPeer(host: remoteHost, port: remotePort)

                                try await withThrowingDiscardingTaskGroup { group in
                                    group.addTask {
                                        for await message in await self.node.getChannel(for: peerID).cancelOnGracefulShutdown() {
                                            try await outbound.write(message)
                                        }
                                        try? await connectionChannel.channel.close()
                                    }
                                    group.addTask {
                                        for try await message in inbound.cancelOnGracefulShutdown() {
                                            do {
                                                try await self.node.processMessage(message, from: peerID)
                                            } catch let error as NodeService.Error {
                                                logger.error("An error has occurred while processing message:\n\(error)")
                                                try await connectionChannel.channel.close()
                                                break // Important that we don't return or continue here as the removal of the peer happens on this task but we don't want to process any more incoming/outgoing messages once an exception occurred.
                                            }
                                            while let message = await self.node.popMessage(peerID) {
                                                try await outbound.write(message)
                                            }
                                        }
                                        // Disconnected
                                        logger.info("Removing incoming peer \(peerID).")
                                        await self.node.removePeer(peerID) // stop sibbling tasks
                                    }
                                }
                            }
                        } catch {
                            logger.error("An unexpected error has occurred:\n\(error)")
                        }
                        await self.clientDisconnected()
                    }
                }
            }
        }
    }
}
