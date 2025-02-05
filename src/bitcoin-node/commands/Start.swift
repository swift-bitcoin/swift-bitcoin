import ArgumentParser
import BitcoinBlockchain
import BitcoinTransport
import ServiceLifecycle
import NIOCore
import NIOPosix

extension NodeNetwork: Decodable, ExpressibleByArgument { }

struct Start: AsyncParsableCommand {

    static let configuration = CommandConfiguration(
        abstract: "Launch a Bitcoin node instance."
    )

    @Option(name: .shortAndLong, help: "The P2P network to connect to.")
    var network = NodeNetwork.main

    @Option(name: .shortAndLong, help: "The address to bind the RPC server to.")
    var host = "0.0.0.0"

    @Option(name: .shortAndLong, help: "The TCP port number to bind the server instance to. Default's to network's default port (\(NodeNetwork.main.defaultRPCPort) for \(NodeNetwork.main))")
    var port: Int?

    mutating func run() async throws {
        let port = port ?? network.defaultRPCPort
        try await launchNode(host: host, port: port)
    }
}

private func launchNode(host: String, port: Int) async throws {

    let blockchain = BlockchainService()
    await blockchain.start()

    let node = NodeService(blockchain: blockchain)

    let eventLoopGroup = MultiThreadedEventLoopGroup(numberOfThreads: System.coreCount)

    let p2pClients = (0 ..< 3).map { _ in
        P2PClient(eventLoopGroup: eventLoopGroup, node: node)
    }

    let p2pService = P2PService(eventLoopGroup: eventLoopGroup, node: node)

    let rpcService = RPCService(host: host, port: port, eventLoopGroup: eventLoopGroup, node: node, blockchain: blockchain, p2pService: p2pService, p2pClients: p2pClients)
    let serviceGroup = ServiceGroup(configuration: .init(
        services: [node] + p2pClients + [p2pService, rpcService],
        gracefulShutdownSignals: [.sigint, .sigterm],
        cancellationSignals: [.sigquit],
        logger: .init(label: "mainServiceGroup")
    ))
    await rpcService.setServiceGroup(serviceGroup)
    try await serviceGroup.run()

    await blockchain.stop()
}
