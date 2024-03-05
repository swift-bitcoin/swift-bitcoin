import Foundation
import Bitcoin
import AsyncAlgorithms
import ServiceLifecycle
import NIO

actor P2PService: Service {

    struct Status {
        var isRunning = false
        var isListening = false
        var host = String?.none
        var port = Int?.none
        var overallTotalConnections = 0
        var connectionsThisSession = 0
        var activeConnections = 0
    }

    init(eventLoopGroup: EventLoopGroup, bitcoinNode: NodeService) {
        self.eventLoopGroup = eventLoopGroup
        self.bitcoinNode = bitcoinNode
    }

    private let eventLoopGroup: EventLoopGroup
    private let bitcoinNode: NodeService
    private(set) var status = Status() // Network status

    private var listenRequests = AsyncChannel<()>() // We'll send () to this channel whenever we want the service to bootstrap itself

    private var serverChannel: NIOAsyncChannel<NIOAsyncChannel<BitcoinMessage, BitcoinMessage>, Never>?
    private var peerIDs = [UUID]()

    func run() async throws {
        // Update status
        status.isRunning = true

        try await withGracefulShutdownHandler {
            for await _ in listenRequests.cancelOnGracefulShutdown() {
                try await startListening()
            }
        } onGracefulShutdown: {
            print("P2P server shutting down gracefully…")
        }
    }

    func start(host: String, port: Int) async {
        guard serverChannel == nil else { return }
        status.host = host
        status.port = port
        await bitcoinNode.setAddress(host, port)
        await listenRequests.send(()) // Signal to start listening
    }

    func stopListening() async throws {
        try await serverChannel?.channel.close()
        serverChannel = .none
        status.isListening = false
        status.host = .none
        status.port = .none
        await bitcoinNode.resetAddress()
    }

    private func updateStats() {
        status.activeConnections -= 1
    }

    private func startListening() async throws {
        guard let host = status.host, let port = status.port else { return }

        // Bootstraping server channel.
        let bootstrap = ServerBootstrap(group: eventLoopGroup)
        let serverChannel = try await bootstrap.bind(
            host: host,
            port: port
        ) { channel in
            // This closure is called for every inbound connection.
            channel.pipeline.addHandlers([
                ByteToMessageHandler(MessageCoder()),
                MessageToByteHandler(MessageCoder())
            ]).eventLoop.makeCompletedFuture {
                try NIOAsyncChannel<BitcoinMessage, BitcoinMessage>(wrappingChannelSynchronously: channel)
            }
        }
        self.serverChannel = serverChannel

        // Accept connections
        try await withThrowingDiscardingTaskGroup { group in
            try await serverChannel.executeThenClose { serverChannelInbound in
                print("P2P server accepting incoming connections on \(host):\(port)…")
                status.isListening = true
                status.port = port
                status.connectionsThisSession = 0
                status.activeConnections = 0

                for try await connectionChannel in serverChannelInbound.cancelOnGracefulShutdown() {

                    print("P2P server received incoming connection from peer @ \(connectionChannel.channel.remoteAddress?.description ?? "").")
                    let remoteHost = connectionChannel.channel.remoteAddress!.ipAddress!
                    let remotePort = connectionChannel.channel.remoteAddress!.port!
                    status.overallTotalConnections += 1
                    status.connectionsThisSession += 1
                    status.activeConnections += 1

                    group.addTask {
                        do {
                            try await connectionChannel.executeThenClose { inbound, outbound in

                                let peerID = await self.bitcoinNode.addPeer(host: remoteHost, port: remotePort)

                                try await withThrowingDiscardingTaskGroup { group in
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
                                                try await connectionChannel.channel.close()
                                            }
                                        }
                                        // Disconnected
                                        print("P2P server disconnected from peer @ \(connectionChannel.channel.remoteAddress?.description ?? "").")
                                        await self.bitcoinNode.removePeer(peerID) // stop sibbling tasks
                                    }
                                }
                            }
                        } catch {
                            // TODO: Handle errors
                            print("Unexpected error:\n\(error.localizedDescription)")
                        }
                        await self.updateStats()
                    }
                }
            }
        }
    }
}
