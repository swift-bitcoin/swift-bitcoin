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

    init(eventLoopGroup: EventLoopGroup, node: NodeService, logger: Logger, host: String, port: Int) {
        self.eventLoopGroup = eventLoopGroup
        self.node = node
        self.logger = logger
        remoteHost = host
        remotePort = port
    }

    let eventLoopGroup: EventLoopGroup
    let node: NodeService
    let logger: Logger
    let remoteHost: String
    let remotePort: Int

    // Status
    private(set) var running = false
    private(set) var connected = false
    private(set) var localPort = Int?.none

    private var clientChannel: NIOAsyncChannel<NetworkMessage, NetworkMessage>?

    var status: StatusRPC.Result.P2PClient {
        .init(running: running, connected: connected, remoteHost: remoteHost, remotePort: remotePort, localPort: localPort)
    }

    /// Runs the stand-by client service but does not attempt to initiate a peer-to-peer connection.
    func run() async throws {
        running = true
        try await withGracefulShutdownHandler {
            try await connectToPeer()
        } onGracefulShutdown: { [logger] in
            logger.info("P2P client shutting down gracefully…")
        }
    }

    func disconnect() async throws {
        try await clientChannel?.channel.close()
    }

    private func connectToPeer() async throws {
        let clientChannel = try await ClientBootstrap(group: eventLoopGroup)
            .connect( host: remoteHost, port: remotePort) { connection in
                connection.eventLoop.makeCompletedFuture {
                    try connection.pipeline.syncOperations.addHandlers([
                        MessageToByteHandler(MessageCoder()),
                        ByteToMessageHandler(MessageCoder()),
                        DebugInboundEventsHandler(),
                        DebugOutboundEventsHandler()
                    ])
                    return try NIOAsyncChannel<NetworkMessage, NetworkMessage>(wrappingChannelSynchronously: connection)
                }
            }

        self.clientChannel = clientChannel
        connected = true
        localPort = clientChannel.channel.localAddress?.port
        logger.info("P2P client @\(localPort ?? -1) connected to peer @\(remoteHost):\(remotePort) ( …")

        try await clientChannel.executeThenClose { @Sendable [logger] inbound, outbound in
            let peerID = await node.addPeer(host: remoteHost, port: remotePort, incoming: false)

            try await withThrowingDiscardingTaskGroup { [logger] group in
                group.addTask {
                    await self.node.connect(peerID)
                    while let message = await self.node.popMessage(peerID) {
                        try await outbound.write(message)
                    }
                    logger.info("Connected \(peerID)")
                }
                group.addTask {
                    for await message in await self.node.getChannel(for: peerID).cancelOnGracefulShutdown() {
                        try await outbound.write(message)
                    }
                    try? await clientChannel.channel.close()
                }
                group.addTask { [logger] in
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
        peerDisconnected() // Clean up, update status
    }

    private func peerDisconnected() {
        logger.info("P2P client @\(localPort ?? -1) disconnected from remote peer @\(remoteHost):\(remotePort)…")
        clientChannel = nil
        running = false
        connected = false
        localPort = nil
    }
}
