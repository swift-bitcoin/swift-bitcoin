import Foundation
import Bitcoin
import AsyncAlgorithms
import ServiceLifecycle
import NIO

actor P2PClientService: Service {

    struct Status {
        var isRunning = false
        var isConnected = false
        var localPort = Int?.none
        var remoteHost = String?.none
        var remotePort = Int?.none
        var overallTotalConnections = 0
    }

    init(eventLoopGroup: EventLoopGroup, bitcoinNode: NodeService) {
        self.eventLoopGroup = eventLoopGroup
        self.bitcoinNode = bitcoinNode
    }

    private let eventLoopGroup: EventLoopGroup
    private let bitcoinNode: NodeService
    private(set) var status = Status() // Network status

    private let connectRequests = AsyncChannel<()>() // We'll send () to this channel whenever we want the service to bootstrap itself

    private var clientChannel: NIOAsyncChannel<BitcoinMessage, BitcoinMessage>?

    func run() async throws {

        status.isRunning = true

        try await withGracefulShutdownHandler {
            for await _ in connectRequests.cancelOnGracefulShutdown() {
                try await connectToPeer()
            }
        } onGracefulShutdown: {
            print("P2P client shutting down gracefully…")
        }
    }

    func connect(host: String, port: Int) async {
        guard clientChannel == nil else { return }
        status.remoteHost = host
        status.remotePort = port
        await connectRequests.send(()) // Signal to connect to remote peer
    }

    func disconnect() async throws {
        try await clientChannel?.channel.close()
    }

    private func connectToPeer() async throws {
        guard let remoteHost = status.remoteHost,
              let remotePort = status.remotePort else { return }

        let clientChannel = try await ClientBootstrap(
            group: eventLoopGroup
        ).connect(
            host: remoteHost,
            port: remotePort
        ) { channel in
            channel.pipeline.addHandlers([
                MessageToByteHandler(MessageCoder()),
                ByteToMessageHandler(MessageCoder())
            ]).eventLoop.makeCompletedFuture {
                try NIOAsyncChannel<BitcoinMessage, BitcoinMessage>(wrappingChannelSynchronously: channel)
            }
        }

        self.clientChannel = clientChannel
        status.isConnected = true
        status.localPort = clientChannel.channel.localAddress?.port
        status.remoteHost = remoteHost
        status.remotePort = remotePort
        status.overallTotalConnections += 1
        print("P2P client @\(status.localPort ?? -1) connected to peer @\(remoteHost):\(remotePort) ( …")

        try await clientChannel.executeThenClose { @Sendable inbound, outbound in
            let peerID = await bitcoinNode.addPeer(host: remoteHost, port: remotePort, incoming: false)

            try await withThrowingDiscardingTaskGroup { group in
                group.addTask {
                    await self.bitcoinNode.connect(peerID)
                    print("Connected \(peerID)")
                }
                group.addTask {
                    for await message in await self.bitcoinNode.getChannel(for: peerID).cancelOnGracefulShutdown() {
                        try await outbound.write(message)
                    }
                }
                group.addTask {
                    for try await message in inbound.cancelOnGracefulShutdown() {
                        do {
                            try await self.bitcoinNode.processMessage(message, from: peerID)
                        } catch is NodeService.Error {
                            try await clientChannel.channel.close()
                        }
                    }
                    // Channel was closed
                    await self.bitcoinNode.removePeer(peerID) // stop sibbling tasks
                }
            }
        }
        peerDisconnected() // Clean up, update status
    }

    private func peerDisconnected() {
        print("P2P client @\(status.localPort ?? -1) disconnected from remote peer @\(status.remoteHost ?? ""):\(status.remotePort ?? -1)…")
        clientChannel = .none
        status.isConnected = false
        status.localPort = .none
        status.remoteHost = .none
        status.remotePort = .none
    }
}
