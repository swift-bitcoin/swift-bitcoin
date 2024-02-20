import Bitcoin
import BitcoinP2P
import AsyncAlgorithms
import ServiceLifecycle
import NIO

public actor P2PClientService: Service {

    public struct Status {
        public var isRunning = false
        public var isConnected = false
        public var localPort = Int?.none
        public var remotePort = Int?.none
        public var overallTotalConnections = 0
    }

    public init(eventLoopGroup: EventLoopGroup, bitcoinService: BitcoinService) {
        self.eventLoopGroup = eventLoopGroup
        self.bitcoinService = bitcoinService
    }

    private let eventLoopGroup: EventLoopGroup
    private let bitcoinService: BitcoinService
    private(set) public var status = Status() // Network status

    private var clientChannel: NIOAsyncChannel<Message, Message>?
    private var peer: BitcoinPeer?

    public func run() async throws {

        status.isRunning = true

        await withGracefulShutdownHandler {

            // We want to keep the service alive while we connect/disconnect from servers. Unless there is a shutdown signal.
            for await _ in AsyncChannel<()>().cancelOnGracefulShutdown() { }

        } onGracefulShutdown: {
            print("P2P client shutting down gracefully…")
        }
    }

    public func connect(_ port: Int) {
        guard clientChannel == nil else { return }
        Task {
            try await connectToPeer(on: port)
        }
    }

    public func disconnect() async throws {
        try await disconnectFromPeer()
    }

    public func ping() async throws {
        try await peer?.sendPing()
    }

    private func connectToPeer(on remotePort: Int) async throws {

        let clientChannel = try await ClientBootstrap(
            group: eventLoopGroup
        ).connect(
            host: "127.0.0.1",
            port: remotePort
        ) { channel in
            channel.pipeline.addHandlers([
                MessageToByteHandler(MessageCoder()),
                ByteToMessageHandler(MessageCoder())
            ]).eventLoop.makeCompletedFuture {
                try NIOAsyncChannel<Message, Message>(wrappingChannelSynchronously: channel)
            }
        }

        self.clientChannel = clientChannel
        status.isConnected = true
        status.localPort = clientChannel.channel.localAddress?.port
        status.remotePort = remotePort
        status.overallTotalConnections += 1
        print("P2P client @\(status.localPort ?? -1) connected to peer @\(remotePort) ( …")

        try await clientChannel.executeThenClose { inbound, outbound in
            let peer = BitcoinPeer(bitcoinService: bitcoinService, isClient: true)
            self.peer = peer

            Task {
                for await message in await peer.messagesOut {
                    try await outbound.write(message)
                }
            }
            Task {
                try await peer.start()
            }
            for try await message in inbound.cancelOnGracefulShutdown() {
                await peer.messagesIn.send(message)
            }

            // Disconnected
            print("P2P client got disconnected from peer @\(remotePort).")
            try await peer.stop()
            status.isConnected = false
            self.peer = .none
        }
    }

    private func disconnectFromPeer() async throws {
        print("P2P client @\(status.localPort ?? -1) disconnecting from remote peer @\(status.remotePort ?? -1)…")
        try await clientChannel?.channel.close()
        clientChannel = .none
        status.isConnected = false
        status.localPort = .none
        status.remotePort = .none
    }
}
