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

    @Option(name: .shortAndLong, help: "Use `default` to use the default location `~/.swift-bitcoin/data` or `in-memory` for ephemeral in-memory database.")
    var dataLocation = "in-memory" // TODO: Allow user to specify a custom path to the config/data directory.

    @Option(name: .shortAndLong, help: "The address to bind the RPC server to.")
    var host = "0.0.0.0"

    @Option(name: .shortAndLong, help: "The TCP port number to bind the server instance to. Default's to network's default port (\(NodeNetwork.main.defaultRPCPort) for \(NodeNetwork.main))")
    var port: Int?

    mutating func run() async throws {
        let port = port ?? network.defaultRPCPort
        try await launchNode(network: network, dataLocation: dataLocation, host: host, port: port)
    }
}

private func launchNode(network: NodeNetwork, dataLocation: String, host: String, port: Int) async throws {
    let params = switch network {
    case .main:
        ConsensusParams.mainnet
    case .test: // TODO: Use real testnet4 params
        ConsensusParams.regtest
    case .signet: // TODO: Use signet params
        ConsensusParams.regtest
    case .regtest:
        ConsensusParams.regtest
    }
    let blockchain = BlockchainService(
        params: params,
        config: .init(dataLocation: dataLocation == "in-memory" ? .memory : .defaultDirectory)
    )
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
