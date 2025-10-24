import Foundation
import NIOPosix
import BitcoinTransport
import JSONRPC
import AsyncAlgorithms
import ServiceLifecycle
import NIOCore
import NIOExtras
import Logging

actor P2PClient: Service {

    init(eventLoopGroup: EventLoopGroup, node: NodeService, logger: Logger, host: String, port: Int, onConnect: (@Sendable (UUID) async -> ())? = nil, onDisconnect: (@Sendable (UUID) async -> ())? = nil) async {
        self.eventLoopGroup = eventLoopGroup
        self.node = node
        self.logger = logger
        remoteHost = host
        remotePort = port
        self.onConnect = onConnect
        self.onDisconnect = onDisconnect
        peerID = await node.addPeer(host: remoteHost, port: remotePort, incoming: false)
    }

    let id = UUID()
    private let eventLoopGroup: EventLoopGroup
    private let node: NodeService
    private let logger: Logger
    let remoteHost: String
    let remotePort: Int
    private var onConnect: (@Sendable (UUID) async -> ())?
    private var onDisconnect: (@Sendable (UUID) async -> ())?
    let peerID: Int

    // Status
    private(set) var connected = false
    private(set) var localPort = Int?.none

    private var clientChannel: NIOAsyncChannel<NetworkMessage, NetworkMessage>?

    var status: StatusRPC.Result.P2PClient {
        .init(peerID: peerID, connected: connected, remoteHost: remoteHost, remotePort: remotePort, localPort: localPort)
    }

    /// Runs the stand-by client service but does not attempt to initiate a peer-to-peer connection.
    func run() async throws {
        try await withGracefulShutdownHandler {
            try await connectToPeer()
        } onGracefulShutdown: { [logger] in
            logger.info("P2P client shutting down gracefully…")
        }
    }

    func setConnectHandler(_ onConnect: (@escaping @Sendable (UUID) async -> ()), onDisconnect: (@escaping @Sendable (UUID) async -> ())) {
        self.onConnect = onConnect
        self.onDisconnect = onDisconnect
    }

    func disconnect() async throws {
        try await clientChannel?.channel.close()
    }

    private func connectToPeer() async throws {
        let bootstrap = ClientBootstrap(group: eventLoopGroup)
        let clientChannel: NIOAsyncChannel<NetworkMessage, NetworkMessage>
        do {
            clientChannel = try await bootstrap.connect( host: remoteHost, port: remotePort) { [logger] connection in
                connection.eventLoop.makeCompletedFuture {
                    try connection.pipeline.syncOperations.addHandlers([
                        MessageToByteHandler(MessageCoder()),
                        ByteToMessageHandler(MessageCoder()),
                        DebugInboundEventsHandler(logger: logger),
                        DebugOutboundEventsHandler(logger: logger)
                    ])
                    return try NIOAsyncChannel<NetworkMessage, NetworkMessage>(wrappingChannelSynchronously: connection)
                }
            }
        } catch let error as NIOConnectionError {
            logger.warning("Could not connect to \(remoteHost):\(remotePort)")
            logger.warning("\(error.description)")
            await node.removePeer(peerID)
            await onDisconnect?(id)
            return
        } catch {
            throw error
        }

        self.clientChannel = clientChannel
        connected = true
        localPort = clientChannel.channel.localAddress?.port
        logger.info("P2P client @\(localPort ?? -1) connected to peer @\(remoteHost):\(remotePort) ( …")
        await onConnect?(id)

        try await clientChannel.executeThenClose { @Sendable [logger] inbound, outbound in

            try await withThrowingDiscardingTaskGroup { [logger] group in
                group.addTask { [peerID] in
                    await self.node.connect(peerID)
                    while let message = await self.node.popMessage(peerID) {
                        try await outbound.write(message)
                    }
                    logger.info("Connected \(peerID)")
                }
                group.addTask { [peerID] in
                    for await message in await self.node.getChannel(for: peerID).cancelOnGracefulShutdown() {
                        try await outbound.write(message)
                    }
                    try? await clientChannel.channel.close()
                }
                group.addTask { [logger, peerID] in
                    for try await message in inbound.cancelOnGracefulShutdown() {
                        do {
                            try await self.node.processMessage(message, from: peerID)
                        } catch let error as NodeService.Error {
                            logger.error("An error has occurred while processing message:\n\(error)")
                            try await clientChannel.channel.close()
                            break // Important that we don't return or continue here as the removal of the peer happens on this task but we don't want to process any more incoming/outgoing messages once an exception occurred.

                        }
                        while let message = await self.node.popMessage(peerID) {
                            try await outbound.write(message)
                        }
                    }
                    // Channel was closed
                    logger.info("Removing outgoing peer \(peerID)")
                    await self.node.removePeer(peerID) // stop sibbling tasks
                }
            }
        }
        await peerDisconnected() // Clean up, update status
    }

    private func peerDisconnected() async {
        logger.info("P2P client disconnected from remote peer \(peerID) @ \(remoteHost):\(remotePort)…")
        clientChannel = nil
        connected = false
        localPort = nil
        await onDisconnect?(id)
    }
}
