import Foundation
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

    @Option(name: .shortAndLong, help: """
        The P2P network to connect to.
        
        During development this value will default to regtest.
    """)
    var network = NodeNetwork.regtest // TODO: Eventually switch to testnet4 and then mainnet.

    @Option(name: .shortAndLong, help: "The absolute path to Swift Bitcoin's data directory (will be created if it does not yet exist). Use value `default` which will point to `~/.swift-bitcoin/data` or use value `in-memory` for ephemeral in-memory database.")
    var dataLocation = "in-memory"

    @Option(name: .shortAndLong, help: "The address to bind the RPC server to.")
    var host = "0.0.0.0"

    @Option(name: .shortAndLong, help: "The TCP port number to bind the server instance to. Default's to network's default port (\(NodeNetwork.main.defaultRPCPort) for \(NodeNetwork.main))")
    var port: Int?

    mutating func run() async throws {
        let port = port ?? network.defaultRPCPort
        try await launchNode(network: network, dataLocation: dataLocation, host: host, port: port)
    }
}

private func launchNode(network: NodeNetwork, dataLocation dataLocationUnresolved: String, host: String, port: Int) async throws {
    let params: ConsensusParams = switch network {
    case .main:
        .mainnet
    case .test: // TODO: Use real testnet4 params
        .regtest
    case .signet: // TODO: Use signet params
        .regtest
    case .regtest:
        .regtest
    }
    let dataLocation: BlockchainService.Config.DataLocation = switch dataLocationUnresolved {
    case "in-memory": .memory
    case "default": .defaultDirectory
    default:.customDirectory(dataLocationUnresolved)
    }
    let blockchain = BlockchainService(
        params: params,
        config: .init(dataLocation: dataLocation)
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
