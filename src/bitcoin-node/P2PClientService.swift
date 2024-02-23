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
        public var remoteHost = String?.none
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

    private var connectRequests = AsyncChannel<()>() // We'll send () to this channel whenever we want the service to bootstrap itself

    private var clientChannel: NIOAsyncChannel<BitcoinMessage, BitcoinMessage>?
    private var peer: BitcoinPeer?

    public func run() async throws {

        status.isRunning = true

        try await withGracefulShutdownHandler {
            for await _ in connectRequests.cancelOnGracefulShutdown() {
                try await connectToPeer()
            }
        } onGracefulShutdown: {
            print("P2P client shutting down gracefully…")
        }
    }

    public func connect(host: String, port: Int) async {
        guard clientChannel == nil else { return }
        status.remoteHost = host
        status.remotePort = port
        await connectRequests.send(()) // Signal to connect to remote peer
    }

    public func disconnect() async throws {
        try await disconnectFromPeer()
    }

    public func ping() async throws {
        try await peer?.sendPing()
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

        try await clientChannel.executeThenClose { inbound, outbound in
            let peer = BitcoinPeer(bitcoinService: bitcoinService, isClient: true)
            self.peer = peer

            try await withThrowingDiscardingTaskGroup { group in
                group.addTask {
                    try await peer.start()
                }
                group.addTask {
                    for await message in await peer.messagesOut.cancelOnGracefulShutdown() {
                        try await outbound.write(message)
                    }
                }
                group.addTask {
                    for try await message in inbound.cancelOnGracefulShutdown() {
                        await peer.messagesIn.send(message)
                    }
                    // Channel was closed
                    try await peer.stop() // stop sibbling tasks
                }
            }
        }
        peerDisconnected() // Clean up, update status
    }

    private func peerDisconnected() {
        print("P2P client @\(status.localPort ?? -1) disconnected from remote peer @\(status.remoteHost ?? ""):\(status.remotePort ?? -1)…")
        clientChannel = .none
        peer = .none
        status.isConnected = false
        status.localPort = .none
        status.remoteHost = .none
        status.remotePort = .none
    }

    private func disconnectFromPeer() async throws {
        try await clientChannel?.channel.close()
    }
}
