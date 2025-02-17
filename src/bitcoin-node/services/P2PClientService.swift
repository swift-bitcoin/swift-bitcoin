import Foundation
import NIOPosix
import BitcoinTransport
import BitcoinRPC
import AsyncAlgorithms
import ServiceLifecycle
import NIOCore
import NIOExtras
import Logging

private let logger = Logger(label: "swift-bitcoin.p2p-client")

actor P2PClient: Service {

    init(eventLoopGroup: EventLoopGroup, node: NodeService) {
        self.eventLoopGroup = eventLoopGroup
        self.node = node
    }

    let eventLoopGroup: EventLoopGroup
    let node: NodeService

    // Status
    private(set) var running = false
    private(set) var connected = false
    private(set) var remoteHost = String?.none
    private(set) var remotePort = Int?.none
    private(set) var localPort = Int?.none
    private(set) var overallConnections = 0

    private let connectRequests = AsyncChannel<()>() // We'll send () to this channel whenever we want the service to bootstrap itself

    private var clientChannel: NIOAsyncChannel<BitcoinMessage, BitcoinMessage>?

    var status: P2PClientStatus {
        .init(running: running, connected: connected, remoteHost: remoteHost, remotePort: remotePort, localPort: localPort, overallConnections: overallConnections)
    }

    /// Runs the stand-by client service but does not attempt to initiate a peer-to-peer connection.
    func run() async throws {
        running = true

        try await withGracefulShutdownHandler {
            for await _ in connectRequests.cancelOnGracefulShutdown() {
                try await connectToPeer()
            }
        } onGracefulShutdown: {
            logger.info("P2P client shutting down gracefully…")
        }
    }

    func connect(host: String, port: Int) async {
        guard clientChannel == nil else { return }
        remoteHost = host
        remotePort = port
        await connectRequests.send(()) // Signal to connect to remote peer
    }

    func disconnect() async throws {
        try await clientChannel?.channel.close()
    }

    private func connectToPeer() async throws {
        guard let remoteHost, let remotePort else {
            logger.error("Missing remote host/port…")
            return
        }

        let clientChannel = try await ClientBootstrap(group: eventLoopGroup)
            .connect( host: remoteHost, port: remotePort) { connection in
                connection.eventLoop.makeCompletedFuture {
                    try connection.pipeline.syncOperations.addHandlers([
                        MessageToByteHandler(MessageCoder()),
                        ByteToMessageHandler(MessageCoder()),
                        DebugInboundEventsHandler(),
                        DebugOutboundEventsHandler()
                    ])
                    return try NIOAsyncChannel<BitcoinMessage, BitcoinMessage>(wrappingChannelSynchronously: connection)
                }
            }

        self.clientChannel = clientChannel
        connected = true
        localPort = clientChannel.channel.localAddress?.port
        overallConnections += 1
        logger.info("P2P client @\(localPort ?? -1) connected to peer @\(remoteHost):\(remotePort) ( …")

        try await clientChannel.executeThenClose { @Sendable inbound, outbound in
            let peerID = await node.addPeer(host: remoteHost, port: remotePort, incoming: false)

            try await withThrowingDiscardingTaskGroup { group in
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
                group.addTask {
                    for try await message in inbound.cancelOnGracefulShutdown() {
                        do {
                            try await self.node.processMessage(message, from: peerID)
                        } catch let error as NodeService.Error {
                            logger.error("An error has occurred while processing message:\n\(error)")
                            try await clientChannel.channel.close()
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
        logger.info("P2P client @\(localPort ?? -1) disconnected from remote peer @\(remoteHost ?? ""):\(remotePort ?? -1)…")
        clientChannel = .none
        connected = false
        localPort = .none
        remoteHost = .none
        remotePort = .none
    }
}
